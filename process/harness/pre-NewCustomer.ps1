param($appPid)
# Simulates the user filling the form; the phone number is pasted from a web page and contains non-breaking spaces.
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
$w=[Windows.Automation.AutomationElement]::FromHandle((Get-Process -Id $appPid).MainWindowHandle)
function Set-Box($id,$text){ $e=$w.FindFirst([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::AutomationIdProperty,$id))); $e.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).SetValue($text); Start-Sleep -Milliseconds 300 }
$nb=[char]0x00A0
Set-Box FullNameBox 'Jordan Lee'
Set-Box EmailBox 'jordan.lee@fabrikam.com'
Set-Box PhoneBox "+1${nb}425${nb}555${nb}0142"
Set-Box PostalCodeBox '98052'
Set-Box CompanyBox 'Fabrikam'
Start-Sleep 1
