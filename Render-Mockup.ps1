# Renders design-source\pixelperfect-mockup.xaml to src\PixelPerfect\design\mockup.png (the PixelPerfect demo's target).
$ErrorActionPreference = 'Stop'
$appRoot = Join-Path (Split-Path $PSScriptRoot) 'XamlAgentDemos'
Push-Location $appRoot
try {
    dotnet build src\PixelPerfect -v q -nologo | Out-Null
    & src\PixelPerfect\bin\Debug\net10.0-windows\PixelPerfect.exe --render-xaml "$PSScriptRoot\design-source\pixelperfect-mockup.xaml" "$appRoot\src\PixelPerfect\design\mockup.png" | Out-Null
    Write-Host "Wrote src\PixelPerfect\design\mockup.png"
}
finally {
    Pop-Location
}
