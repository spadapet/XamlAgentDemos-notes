param([string]$Log, [int]$TimeoutSec = 900, [int]$DelayMs = 400)
# Waits for the Accessibility Checker pane's Stop button to become enabled (a check is running), then presses it once.
Import-Module "$PSScriptRoot\Harness.psm1" -Force -WarningAction SilentlyContinue
function L($m) { $l = "[$(Get-Date -Format HH:mm:ss.fff)] $m"; if ($Log) { Add-Content $Log $l }; Write-Host $l }
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$cond = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Button)
while ((Get-Date) -lt $deadline) {
    try {
        $pane = Find-Ui NameProperty 'Accessibility Checker'
        if ($pane) {
            foreach ($b in $pane.FindAll([Windows.Automation.TreeScope]::Descendants, $cond)) {
                $n = $b.Current.Name
                if ($n -match 'Stop|Cancel' -and $b.Current.IsEnabled) {
                    L "Stop button '$n' enabled; pressing in $DelayMs ms"
                    Start-Sleep -Milliseconds $DelayMs
                    Invoke-Ui $b
                    L "Pressed Stop"
                    return
                }
            }
        }
    } catch { }
    Start-Sleep -Milliseconds 100
}
L "Timed out waiting for the Stop button"
