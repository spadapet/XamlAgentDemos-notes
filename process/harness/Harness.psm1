Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Windows.Forms
if(-not ("Rot" -as [type])){ Add-Type -Path "$PSScriptRoot\Rot.cs" }
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W32b {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern void keybd_event(byte k,byte s,uint f,UIntPtr e);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
}
"@
$script:DialogLog = $null
$script:SessRoot = "$env:LOCALAPPDATA\Microsoft\VisualStudio\CopilotCli\session-state"
if(-not ("VsWin" -as [type])){ Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public static class VsWin {
 public delegate bool P(IntPtr h,IntPtr l);
 [DllImport("user32.dll")] static extern bool EnumWindows(P p,IntPtr l);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
 public static IntPtr FindMain(uint pid){ IntPtr r=IntPtr.Zero; EnumWindows((h,l)=>{ uint p; GetWindowThreadProcessId(h,out p); if(p==pid){ var t=new StringBuilder(512); GetWindowText(h,t,512); if(t.ToString().Contains("Microsoft Visual Studio")){ r=h; return false; } } return true; },IntPtr.Zero); return r; }
}
"@ }function Get-VsPid { (Get-Process devenv | ? Path -like 'C:\vs\fastmain\*' | select -First 1).Id }
function Get-Dte { [Rot]::Get("!VisualStudio.DTE.18.0:$(Get-VsPid)") }
function Get-VsMainHwnd {
  $p=Get-Process -Id (Get-VsPid)
  if($p.MainWindowHandle -ne 0){ return $p.MainWindowHandle }
  # VS main window sometimes becomes hidden after F5; find and re-show it.
  $h=[VsWin]::FindMain([uint32]$p.Id)
  if($h -ne [IntPtr]::Zero){ [VsWin]::ShowWindow($h,5)|Out-Null; Start-Sleep 1; Write-Host "[harness] re-showed hidden VS main window" }
  return $h
}
function Get-VsRoot { [Windows.Automation.AutomationElement]::FromHandle((Get-VsMainHwnd)) }
function Find-Ui($prop,$val,$scope=$null) {
  if(-not $scope){$scope=Get-VsRoot}
  $c=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::$prop,$val)
  $scope.FindFirst([Windows.Automation.TreeScope]::Descendants,$c)
}
function Get-ChatInput { Find-Ui NameProperty 'Ask Copilot' }
function Get-ChatInputText { $e=Get-ChatInput; $e.GetCurrentPattern([Windows.Automation.TextPattern]::Pattern).DocumentRange.GetText(-1) }
function Invoke-Ui($el){ $el.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke() }
function Focus-Vs { $h=Get-VsMainHwnd; [W32b]::keybd_event(0x12,0,0,[UIntPtr]::Zero); [W32b]::keybd_event(0x12,0,2,[UIntPtr]::Zero); [W32b]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 300 }
function Click-Element($e){ $r=$e.Current.BoundingRectangle; [System.Windows.Forms.Cursor]::Position=New-Object Drawing.Point([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); [W32b]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [W32b]::mouse_event(4,0,0,0,[UIntPtr]::Zero) }
function Send-Keys([string]$k){ for($j=0;$j -lt 5;$j++){ try { [System.Windows.Forms.SendKeys]::SendWait($k); return } catch { Start-Sleep -Milliseconds 700; Focus-Vs } }; throw "SendWait($k) failed" }
function Set-ChatText([string]$text) {
  $focused=$false
  for($i=0;$i -lt 6 -and -not $focused;$i++){
    $h=Get-VsMainHwnd; [W32b]::ShowWindow($h,5) | Out-Null
    Focus-Vs
    $e=Get-ChatInput
    try { $e.SetFocus(); $focused=$true } catch { try { [System.Windows.Forms.SendKeys]::SendWait('{ESC}') } catch {}; if($i -ge 2 -and $e){ try { Click-Element $e; $focused=$true } catch {} } ; Start-Sleep 2 }
  }
  if(-not $focused){ throw "Could not focus chat input" }
  Start-Sleep -Milliseconds 300
  Set-Clipboard -Value $text
  Send-Keys '^a'; Start-Sleep -Milliseconds 100
  Send-Keys '^v'; Start-Sleep -Milliseconds 500
  (Get-ChatInputText).Trim()
}
function Get-LatestSessionDir { Get-ChildItem $script:SessRoot -Directory | ? Name -ne '.session-operation-locks' | sort LastWriteTime -desc | select -First 1 }
function Send-ChatPrompt([string]$text) {
  for($try=0;$try -lt 4;$try++){
    $got=Set-ChatText $text
    if($got -eq $text.Trim()){ break }
    Start-Sleep 2
  }
  if($got -ne $text.Trim()){ throw "Chat input mismatch: [$got]" }
  Invoke-Ui (Find-Ui AutomationIdProperty 'SendButton')
}
function Read-Events($dir){ Get-Content "$dir\events.jsonl" | % { $_ | ConvertFrom-Json } }
function Wait-ChatTurn($dir,[int]$afterLines,[int]$timeoutSec=1800) {
  $sw=[Diagnostics.Stopwatch]::StartNew()
  while($sw.Elapsed.TotalSeconds -lt $timeoutSec){
    Start-Sleep 5
    $lines=Get-Content "$dir\events.jsonl"
    if($lines.Count -gt $afterLines){
      $new=$lines[$afterLines..($lines.Count-1)] | % { ($_|ConvertFrom-Json).type }
      if($new -contains 'session.shutdown' -or $new -contains 'session.idle'){ return $true }
    }
  }
  return $false
}


function Invoke-Dte([scriptblock]$sb) {
  for($i=0;$i -lt 60;$i++){ try { return & $sb } catch { if($_.Exception.HResult -in 0x80010001,0x8001010A -or $_.Exception.Message -match 'busy|rejected'){ Close-Asserts $script:DialogLog | Out-Null; Start-Sleep 2 } else { throw } } }
  throw "DTE busy"
}
function Start-Demo([string]$name) {
  Close-Asserts $script:DialogLog | Out-Null
  $dte=Get-Dte
  Invoke-Dte { $dte.Solution.SolutionBuild.StartupProjects = "src\$name\$name.csproj" } | Out-Null
  Invoke-Dte { $dte.Debugger.Go($false) } | Out-Null
  $sw=[Diagnostics.Stopwatch]::StartNew()
  while($sw.Elapsed.TotalSeconds -lt 300){
    Start-Sleep 3
    Close-Asserts $script:DialogLog | Out-Null
    $proc=Get-Process $name -ErrorAction SilentlyContinue | ? MainWindowHandle -ne 0
    $mode=Invoke-Dte { $dte.Debugger.CurrentMode }
    if($proc -and $mode -eq 3){ Start-Sleep 8; return $proc.Id }
  }
  throw "Demo $name did not start (mode=$mode)"
}
function Stop-Demo { Close-Asserts $script:DialogLog | Out-Null; $dte=Get-Dte; if((Invoke-Dte { $dte.Debugger.CurrentMode }) -ne 1){ Invoke-Dte { $dte.Debugger.Stop($true) } | Out-Null }; Start-Sleep 3 }
function Reset-Demos { git -C Q:\source\XamlAgentDemos checkout -- . ; git -C Q:\source\XamlAgentDemos clean -fdq }
function New-ChatThread {
  for($i=0;$i -lt 10;$i++){
    Focus-Vs
    $b=Find-Ui AutomationIdProperty 'createNewThread'
    if($b){ try { Invoke-Ui $b } catch {} ; Start-Sleep 3 }
    else { try { (Get-Dte).ExecuteCommand('View.GitHub.Copilot.Chat') } catch {}; Start-Sleep 3 }
    if(Get-ChatInput){ return }
  }
  throw 'New-ChatThread: chat input not available'
}
function Save-VsScreenshot([string]$path) {
  Add-Type -AssemblyName System.Drawing
  $r=(Get-VsRoot).Current.BoundingRectangle
  $bmp=New-Object Drawing.Bitmap ([int]$r.Width),([int]$r.Height); $g=[Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen([int]$r.X,[int]$r.Y,0,0,$bmp.Size); $bmp.Save($path); $g.Dispose(); $bmp.Dispose()
}
function Find-SessionDirForPrompt([string]$prompt,[datetime]$since) {
  $snip=$prompt.Substring(0,[Math]::Min(40,$prompt.Length))
  for($i=0;$i -lt 60;$i++){
    foreach($dir in Get-ChildItem $script:SessRoot -Directory | ? { $_.Name -ne '.session-operation-locks' -and $_.LastWriteTime -gt $since }){
      $ev="$($dir.FullName)\events.jsonl"
      # events.jsonl is JSON: backslashes are doubled and some chars may be \u-escaped
      $esc=$snip.Replace('\','\\').Replace('"','\"')
      $cands=@($snip,$esc,$esc.Replace("'",'\u0027'))
      if((Test-Path $ev) -and (Select-String -Path $ev -SimpleMatch $cands -Quiet)){ return $dir.FullName }
    }
    Start-Sleep 2
  }
  throw "session dir not found"
}
function Wait-TurnDone([string]$dir,[int]$afterLines,[int]$timeoutSec=2700) {
  $sw=[Diagnostics.Stopwatch]::StartNew(); $lastCount=0; $quiet=[Diagnostics.Stopwatch]::StartNew()
  while($sw.Elapsed.TotalSeconds -lt $timeoutSec){
    Start-Sleep 10
    Close-Asserts $script:DialogLog
    Close-VsDialogs $script:DialogLog | Out-Null
    $lines=@(Get-Content "$dir\events.jsonl")
    if($lines.Count -ne $lastCount){ $lastCount=$lines.Count; $quiet.Restart() }
    if($lines.Count -gt $afterLines){
      $types=$lines[$afterLines..($lines.Count-1)] | % { try { ($_|ConvertFrom-Json).type } catch {} }
      if($types -contains 'session.task_complete' -or $types -contains 'session.shutdown'){ Start-Sleep 5; return 'done' }
      if($types -contains 'assistant.turn_end' -and $quiet.Elapsed.TotalSeconds -gt 30 -and (Find-Ui AutomationIdProperty 'SendButton')){ return 'idle' }
    }
    if(Approve-PendingPermission $script:DialogLog){ $quiet.Restart() }
    if($quiet.Elapsed.TotalSeconds -gt 900){ return 'stalled' }
  }
  return 'timeout'
}

function Set-Autopilot {
  $desk=[Windows.Automation.AutomationElement]::RootElement
  $menuItem=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::MenuItem)
  for($i=0;$i -lt 4;$i++){
    $m=Find-Ui AutomationIdProperty 'ConversationModeSelector'
    if($m.Current.Name -match 'Autopilot'){ return }
    try { $m.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand() } catch {}
    Start-Sleep 2
    $a=$desk.FindFirst([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.AndCondition($menuItem,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,'Autopilot')))))
    if($a){ Invoke-Ui $a; Start-Sleep 2 }
    else { [Console]::Error.WriteLine("Set-Autopilot try $i items: " + (($desk.FindAll([Windows.Automation.TreeScope]::Descendants,$menuItem) | % { $_.Current.Name }) -join ' | ')); Start-Sleep 3 }
  }
  if((Find-Ui AutomationIdProperty 'ConversationModeSelector').Current.Name -notmatch 'Autopilot'){ throw 'Autopilot not set' }
}
function Close-Asserts([string]$logFile) {
  # Checked-build asserts block the VS UI thread, so UIA hangs; use Win32 and send IDIGNORE (5).
  if(-not ('AssertWin' -as [type])){
    Add-Type @'
using System;using System.Runtime.InteropServices;using System.Text;using System.Collections.Generic;
public static class AssertWin{delegate bool P(IntPtr h,IntPtr l);
[DllImport("user32")]static extern bool EnumWindows(P p,IntPtr l);
[DllImport("user32")]static extern bool EnumChildWindows(IntPtr h,P p,IntPtr l);
[DllImport("user32",CharSet=CharSet.Unicode)]static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
[DllImport("user32")]static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32")]static extern IntPtr PostMessage(IntPtr h,int m,IntPtr w,IntPtr l);
static string T(IntPtr h){var s=new StringBuilder(4096);GetWindowText(h,s,4096);return s.ToString();}
public static List<string> Dismiss(){var r=new List<string>();
EnumWindows((h,l)=>{if(IsWindowVisible(h)&&T(h).StartsWith("Assertion Failed")){var sb=new StringBuilder();
EnumChildWindows(h,(c,x)=>{var t=T(c);if(t.Length>sb.Length&&t.Length>20){sb.Clear();sb.Append(t);}return true;},IntPtr.Zero);
r.Add(sb.ToString());PostMessage(h,0x0111,(IntPtr)5,IntPtr.Zero);}return true;},IntPtr.Zero);return r;}}
'@
  }
  foreach($text in [AssertWin]::Dismiss()){
    $first=($text -split "`n" | Select-Object -First 3) -join ' / '
    if($logFile){ Add-Content $logFile "[$(Get-Date -f HH:mm:ss)] ASSERT ignored: $first" }
  }
}

function Approve-PendingPermission([string]$logFile) {
  $btn=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Button)
  foreach($name in 'Allow this time','Allow'){
    $cond=New-Object Windows.Automation.AndCondition((New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::IsInvokePatternAvailableProperty,$true)),(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,$name)))
    $b=(Get-VsRoot).FindFirst([Windows.Automation.TreeScope]::Descendants,$cond)
    if($b -and $b.Current.IsEnabled -and -not $b.Current.IsOffscreen){
      $texts=''
      try { $w=[Windows.Automation.TreeWalker]::ControlViewWalker; $p=$w.GetParent($w.GetParent($b)); $texts=(($p.FindAll([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Text))) | % { $_.Current.Name }) -join ' | ') } catch {}
      try { Invoke-Ui $b } catch { Click-Element $b }
      if($logFile){ Add-Content $logFile "[$(Get-Date -Format HH:mm:ss)] PERMISSION '$name' :: $texts" }
      return $true
    }
  }
  return $false
}



function Get-VsDialogs {
  $vsPid=Get-VsPid; $desk=[Windows.Automation.AutomationElement]::RootElement; $res=@()
  foreach($w in $desk.FindAll([Windows.Automation.TreeScope]::Children,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty,$vsPid)))){
    $res+=$w.FindAll([Windows.Automation.TreeScope]::Children,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Window)))
    if($w.Current.Name -notmatch 'Microsoft Visual Studio'){ $res+=$w }
  }
  $res
}
function Close-VsDialogs([string]$logFile) {
  $n=0
  foreach($dlg in Get-VsDialogs){
    $title=$dlg.Current.Name
    $texts=($dlg.FindAll([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Text))) | % { $_.Current.Name }) -join ' / '
    $btnName = if($title -like 'Hot Reload*'){ 'Disable' } else { $null }
    foreach($cand in @($btnName,'OK','Close','Cancel','No') | ? { $_ }){
      $b=$dlg.FindFirst([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.AndCondition((New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Button)),(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,$cand)))))
      if($b){ try { Invoke-Ui $b; $n++; if($logFile){ Add-Content $logFile "[$(Get-Date -Format HH:mm:ss)] DIALOG '$title' -> $cand :: $texts" }; break } catch {} }
    }
  }
  $n
}



