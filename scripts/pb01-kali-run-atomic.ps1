$ErrorActionPreference = 'Stop'
$guid = '9d3c97df-01f6-44b8-b28e-4a56e2d781eb'
$folder = '/home/kali/AtomicRedTeam/atomics'
$log = '/tmp/pb01-atomic-run.log'
try {
    Import-Module Invoke-AtomicRedTeam -ErrorAction Stop
    "start_utc=$((Get-Date).ToUniversalTime().ToString('o'))" | Set-Content $log
    Invoke-AtomicTest T1110.003 -TestGuids $guid -PathToAtomicsFolder $folder -CheckPrereqs -Confirm:$false *>&1 |
        Out-String | Add-Content $log
    Invoke-AtomicTest T1110.003 -TestGuids $guid -PathToAtomicsFolder $folder -Confirm:$false *>&1 |
        Out-String | Add-Content $log
    "end_utc=$((Get-Date).ToUniversalTime().ToString('o'))" | Add-Content $log
} catch {
    "ERROR: $($_.Exception.Message)" | Add-Content $log
    exit 1
}
