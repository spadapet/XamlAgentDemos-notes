$ErrorActionPreference = 'Stop'
$path = 'C:\vs\fastmain\Common7\IDE\devenv.exe.config'
$bytes = [IO.File]::ReadAllBytes($path)
$offset = 0
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $offset = 3
    $encoding = [Text.UTF8Encoding]::new($false)
}
elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    $offset = 2
    $encoding = [Text.UnicodeEncoding]::new($false, $false)
}
else {
    $encoding = [Text.UTF8Encoding]::new($false)
}

$text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
$pattern = '(?s)(<assemblyIdentity\s+name="System\.Drawing\.Common"[^>]*/>\s*<bindingRedirect\s+oldVersion="[^"]+"\s+newVersion=")10\.0\.0\.14(" />)'
$matches = [regex]::Matches($text, $pattern)
if ($matches.Count -ne 1) {
    throw "Expected one System.Drawing.Common redirect to 10.0.0.14; found $($matches.Count)."
}

$updatedText = [regex]::Replace(
    $text,
    $pattern,
    [System.Text.RegularExpressions.MatchEvaluator] {
        param($match)
        $match.Groups[1].Value + '10.0.0.0' + $match.Groups[2].Value
    })
$content = $encoding.GetBytes($updatedText)
$updated = [byte[]]::new($offset + $content.Length)
if ($offset -gt 0) {
    [Array]::Copy($bytes, 0, $updated, 0, $offset)
}
[Array]::Copy($content, 0, $updated, $offset, $content.Length)
[IO.File]::WriteAllBytes($path, $updated)
Write-Output 'Updated System.Drawing.Common redirect to assembly version 10.0.0.0.'
