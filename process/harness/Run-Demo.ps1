param([string]$Name,[string]$Prompt,[string]$Tag='run1',[switch]$NoFollowUp,[switch]$KeepRunning,[string]$ResumeDir,[string[]]$FollowUps)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot\Harness.psm1" -Force -WarningAction SilentlyContinue
if(-not $Prompt -and -not $ResumeDir){ $Prompt=(Get-Content "$PSScriptRoot\prompts.json" -Raw | ConvertFrom-Json).$Name }
$outDir="Q:\source\XamlAgentDemos-notes\test-runs\$Name\$Tag"; New-Item -ItemType Directory -Force $outDir | Out-Null
Set-Variable -Name DialogLog -Scope Script -Value "$outDir\dialogs.log" -Force; (Get-Module Harness).SessionState.PSVariable.Set("DialogLog","$outDir\dialogs.log")
function Log($m){ $l="[$(Get-Date -Format HH:mm:ss)] $m"; Add-Content "$outDir\runner.log" $l; Write-Host $l }
$FollowUp = "Thanks. Now some quick feedback for the tooling team. Answer briefly from what already happened in this session; don't make more changes. (1) Which xaml_* tools or skill guidance helped most? (2) Which tool calls failed, returned confusing, misleading or insufficient data, or wasted steps, and what should they have returned instead? (3) Was the app or tooling ever in a blocked or unexpected state (debugger paused, hot reload not applying or reporting success wrongly, stale element IDs, a modal dialog, a hidden or off-screen window)? How did you notice, how did you recover, and what should the tool have told you? (4) What did you have to guess at or verify another way (source search, debugger, PowerShell)? (5) Which fixes did you verify live in the running app, and which only in source, and why? (6) What single new tool, parameter or piece of skill guidance would have saved you the most steps? (7) Re-read my original request: did you meet every explicit requirement in it? If you skipped, merged or changed any of them, say which and why."
if(-not $ResumeDir){
Log "Stop + reset"; Stop-Demo; $dte=Get-Dte; Invoke-Dte { $dte.Documents.CloseAll(2) } | Out-Null; Reset-Demos
Log "Start $Name"; $appPid=Start-Demo $Name; Log "App pid $appPid"
if(Test-Path "$PSScriptRoot\pre-$Name.ps1"){ Log "Pre-action"; & "$PSScriptRoot\pre-$Name.ps1" $appPid }
New-ChatThread; Set-Autopilot
$since=(Get-Date).AddSeconds(-5)
Log "Send prompt"; Send-ChatPrompt $Prompt
$dir=Find-SessionDirForPrompt $Prompt $since; Log "Session $dir"
} else { $dir=$ResumeDir }
$r=Wait-TurnDone $dir 0; Log "Main turn: $r"
foreach($u in $FollowUps){
  Start-Sleep 5; $n=@(Get-Content "$dir\events.jsonl").Count
  try { Close-VsDialogs $null | Out-Null; Log "Send user turn: $u"; Send-ChatPrompt $u; $r=Wait-TurnDone $dir $n; Log "User turn: $r" } catch { Log "User turn ERROR $_" }
}
if(-not $NoFollowUp){
  Start-Sleep 5; $n=@(Get-Content "$dir\events.jsonl").Count
  try {
    Close-VsDialogs $null | Out-Null; Log "Send follow-up"; Send-ChatPrompt $FollowUp
    $r=Wait-TurnDone $dir $n 900; Log "Follow-up: $r"
  } catch { Log "Follow-up ERROR $_" }
}
Copy-Item "$dir\events.jsonl" "$outDir\events.jsonl" -Force
node "$PSScriptRoot\render.js" "$outDir\events.jsonl" "$outDir\transcript.md" | % { Log "Stats $_" }
git -C Q:\source\XamlAgentDemos diff > "$outDir\fix.diff"
git -C Q:\source\XamlAgentDemos status --short > "$outDir\status.txt"
try { Save-VsScreenshot "$outDir\vs-final.png" } catch { Log "screenshot failed $_" }
Close-VsDialogs "$outDir\dialogs.log" | Out-Null
try { $m=(Get-Dte).Debugger.CurrentMode; Log "Debugger mode at end: $m (1=design 2=break 3=run)" } catch {}
if(-not $KeepRunning){ Stop-Demo }
Log "Finished"




