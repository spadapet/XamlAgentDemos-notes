param([string]$Log, [int]$TimeoutSec = 600)
# When the newest Copilot session logs a completed xaml_get_status, presses Run in the Accessibility Checker pane,
# so the agent's following xaml_run_accessibility_check finds a check already running.
Import-Module "$PSScriptRoot\Harness.psm1" -Force -WarningAction SilentlyContinue
function L($m) { $l = "[$(Get-Date -Format HH:mm:ss.fff)] $m"; if ($Log) { Add-Content $Log $l }; Write-Host $l }
$root = "$env:LOCALAPPDATA\Microsoft\VisualStudio\CopilotCli\session-state"
$start = Get-Date
$deadline = $start.AddSeconds($TimeoutSec)
$cond = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Button)
while ((Get-Date) -lt $deadline) {
    $d = Get-ChildItem $root -Directory | ? { $_.Name -ne '.session-operation-locks' -and $_.CreationTime -gt $start } | sort LastWriteTime -desc | select -First 1
    if ($d -and (Test-Path "$($d.FullName)\events.jsonl") -and (Select-String -Path "$($d.FullName)\events.jsonl" -Pattern 'tool.execution_complete' -Quiet) -and (Select-String -Path "$($d.FullName)\events.jsonl" -Pattern 'xaml_get_status' -Quiet)) {
        $pane = Find-Ui NameProperty 'Accessibility Checker'
        foreach ($b in $pane.FindAll([Windows.Automation.TreeScope]::Descendants, $cond)) {
            if ($b.Current.Name -match '^Run' -and $b.Current.IsEnabled) { Invoke-Ui $b; L "Pressed '$($b.Current.Name)' in the pane"; return }
        }
        L "Run button not found or disabled"; return
    }
    Start-Sleep -Milliseconds 100
}
L "Timed out"
