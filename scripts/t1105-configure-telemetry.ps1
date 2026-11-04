param([string]$Stage = 'C:\Windows\Temp\datn-t1105')
$ErrorActionPreference = 'Stop'
Start-Transcript -Path (Join-Path $Stage 'telemetry-install.log') -Force | Out-Null
try {
    $sysmon = 'C:\Windows\Temp\datn-t1059\Sysmon64.exe'
    $config = 'C:\Program Files\Winlogbeat\winlogbeat.yml'
    if (!(Test-Path $sysmon) -or !(Test-Path $config)) { throw 'Expected existing Sysmon and Winlogbeat missing' }
    & $sysmon -c | Out-File -Encoding utf8 (Join-Path $Stage 'sysmon-before.txt')
    Copy-Item -LiteralPath $config -Destination (Join-Path $Stage 'winlogbeat-before.yml') -Force
    $text = Get-Content -LiteralPath $config -Raw
    if ($text -notmatch 'event_id:\s*1,\s*3\s*(\r?\n)') { throw 'Unexpected Winlogbeat event list; no changes made' }
    & $sysmon -c (Join-Path $Stage 'sysmon-t1105-lab.xml')
    if ($LASTEXITCODE -ne 0) { throw 'Sysmon configuration failed' }
    $text = $text -replace 'event_id:\s*1,\s*3\s*(\r?\n)', 'event_id: 1, 3, 11${1}'
    [IO.File]::WriteAllText($config, $text, [Text.UTF8Encoding]::new($false))
    & 'C:\Program Files\Winlogbeat\winlogbeat.exe' test config -c $config
    if ($LASTEXITCODE -ne 0) {
        Copy-Item -LiteralPath (Join-Path $Stage 'winlogbeat-before.yml') -Destination $config -Force
        throw 'Winlogbeat config invalid; restored previous file'
    }
    Restart-Service winlogbeat
    Get-Service Sysmon64,winlogbeat | Format-Table Name,Status,StartType -AutoSize
    'TELEMETRY_CONFIG=SUCCESS'
} catch {
    "TELEMETRY_CONFIG=FAILED: $($_.Exception.Message)"
    exit 1
} finally { Stop-Transcript | Out-Null }
