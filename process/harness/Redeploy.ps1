$ErrorActionPreference='Continue'
Import-Module "$PSScriptRoot\Harness.psm1" -Force 3>$null
try { Stop-Demo } catch {}
try { (Get-Dte).Quit() } catch { "quit err $_" }
$deadline=(Get-Date).AddSeconds(120)
while ((Get-Process devenv -EA 0 | ? { $_.Path -like 'C:\vs\fastmain*' }) -and (Get-Date) -lt $deadline) { Start-Sleep 3 }
$left=@(Get-Process devenv -EA 0 | ? { $_.Path -like 'C:\vs\fastmain*' })
if ($left.Count) { "devenv still running: $($left.Id -join ',')"; return }
$log="$env:TEMP\deploy.log"
Start-Process pwsh -Verb RunAs -Wait -ArgumentList @('-NoProfile','-Command',"& 'Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1' -VSInstallPath 'C:\vs\fastmain' -Diagnostics -NonInteractive *> '$log'")
Get-Content $log -Tail 2
$redirect = Select-String C:\vs\fastmain\Common7\IDE\devenv.exe.config -Pattern 'System.Drawing.Common' -Context 0,1 | % { $_.Context.PostContext }
"redirect: $redirect"
if ("$redirect" -notmatch 'newVersion="10.0.0.0"') { "REDIRECT LOST - run Patch-DrawingRedirect.ps1"; return }
Start-Process C:\vs\fastmain\Common7\IDE\devenv.exe -ArgumentList '/rootsuffix','Exp','Q:\source\XamlAgentDemos\XamlAgentDemos.sln'
Start-Sleep 90
Import-Module "$PSScriptRoot\Harness.psm1" -Force 3>$null
New-ChatThread
"relaunched"
