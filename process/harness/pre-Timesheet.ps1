param($appPid)
# Simulates the user correcting Wednesday to seven and a half hours, typed with a decimal comma.
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
$w=[Windows.Automation.AutomationElement]::FromHandle((Get-Process -Id $appPid).MainWindowHandle)
$e=$w.FindFirst([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.AndCondition((New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,'Wednesday')),(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Edit)))))
$e.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).SetValue('7,5'); Start-Sleep 1
