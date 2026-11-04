$ErrorActionPreference = 'Stop'
$source='C:\DATN-T1105\incoming\t1105-lab-sample.txt'
$backup='C:\DATN-T1105\incoming\t1105-lab-sample.saved'
$expected='613DBDF3F2E76FF5773E8A5C6D09D6278A907F985108E33DB7C62E772635A754'
$result='C:\Windows\Temp\datn-t1105\hash-guard-test.json'
if (Test-Path -LiteralPath $backup) { throw 'Backup path exists; refusing to proceed' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne $expected) { throw 'Sample hash mismatch; refusing to proceed' }
Move-Item -LiteralPath $source -Destination $backup
try {
    [IO.File]::WriteAllText($source,'DATN test data with wrong hash')
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Windows\Temp\datn-t1105\quarantine.ps1' -Action Quarantine 2>&1 | Out-Null
    $exitCode=$LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $response=Get-Content 'C:\Windows\Temp\datn-t1105\response.json' -Raw | ConvertFrom-Json
    if ($exitCode -eq 0 -or $response.status -ne 'FAILED' -or $response.reason -notmatch 'SHA256') { throw 'Hash guard did not reject modified test data' }
    @{test='different-sha256'; result='PASS'; guest_exit=$exitCode; reason=$response.reason; time_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $result -Encoding UTF8
} finally {
    if ((Test-Path -LiteralPath $source) -and (Get-Content -LiteralPath $source -Raw) -eq 'DATN test data with wrong hash') { Remove-Item -LiteralPath $source }
    if (!(Test-Path -LiteralPath $source) -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $source }
}
