param([string[]]$Dirs)
foreach ($d in $Dirs) {
    $ev = Get-Content "$d\events.jsonl" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json -Depth 50 }
    $starts = @{}
    foreach ($e in $ev | Where-Object type -eq 'tool.execution_start') { $starts[$e.data.toolCallId] = $e.data }
    "== $d"
    $times = $ev | ForEach-Object { [datetime]$_.timestamp }
    "duration_min {0:N1}" -f (($times | Measure-Object -Maximum).Maximum - ($times | Measure-Object -Minimum).Minimum).TotalMinutes
    "tools " + (($starts.Values | Group-Object toolName | Sort-Object Count -Descending | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', ')
    $failed = @()
    foreach ($e in $ev | Where-Object type -eq 'tool.execution_complete') {
        $s = $starts[$e.data.toolCallId]; $name = if ($s) { $s.toolName } else { '?' }
        $content = ($e.data.result | ConvertTo-Json -Depth 10 -Compress)
        if ($content.Length -gt 4000) { $content = $content.Substring(0, 4000) }
        if (-not $e.data.success -or ($name -like 'xaml_*' -and $content -match '\\"error\\"')) {
            $a = ($s.arguments | ConvertTo-Json -Compress -Depth 5); if ($a.Length -gt 200) { $a = $a.Substring(0, 200) }
            $failed += "  FAIL $name $a :: " + $content.Substring(0, [Math]::Min(400, $content.Length))
        }
    }
    "failed $($failed.Count)"; $failed
    foreach ($e in $ev | Where-Object { $_.type -eq 'tool.execution_start' -and $_.data.toolName -eq 'task_complete' }) {
        $x = ($e.data.arguments | ConvertTo-Json -Compress); "TASK_COMPLETE: " + $x.Substring(0, [Math]::Min(2500, $x.Length))
    }
    $fb = $null
    for ($i = 0; $i -lt $ev.Count; $i++) {
        if ($ev[$i].type -eq 'user.message' -and "$($ev[$i].data.content)".StartsWith('Thanks.')) {
            for ($j = $i + 1; $j -lt $ev.Count; $j++) {
                if ($ev[$j].type -eq 'assistant.message' -and $ev[$j].data.content) { $fb = $ev[$j].data.content; break }
            }
        }
    }
    "FEEDBACK: $fb"
    ""
}
