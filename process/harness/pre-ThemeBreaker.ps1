param($appPid)
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
$w=[Windows.Automation.AutomationElement]::FromHandle((Get-Process -Id $appPid).MainWindowHandle)
$b=$w.FindFirst([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::AutomationIdProperty,'DarkModeToggle')))
$b.GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern).Toggle(); Start-Sleep 2
