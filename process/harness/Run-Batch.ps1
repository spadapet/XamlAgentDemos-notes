param([string[]]$Names,[string]$Tag='run1')
$p=Get-Content "$PSScriptRoot\prompts.json" -Raw | ConvertFrom-Json
foreach($n in $Names){ try { & "$PSScriptRoot\Run-Demo.ps1" -Name $n -Tag $Tag -Prompt $p.$n } catch { Write-Host "[$n] ERROR $_"; Add-Content "Q:\source\XamlAgentDemos-notes\test-runs\$n\$Tag\runner.log" "ERROR $_ $($_.ScriptStackTrace)" } }
