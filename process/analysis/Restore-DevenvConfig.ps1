$ErrorActionPreference = 'Stop'
$source = 'C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\devenv.exe.config.before-a11y-test'
$destination = 'C:\vs\fastmain\Common7\IDE\devenv.exe.config'
if (-not (Test-Path -LiteralPath $source)) {
    throw "Configuration backup not found: $source"
}
[IO.File]::Copy($source, $destination, $true)
Write-Output 'Restored devenv.exe.config from the pre-test backup.'
