param(
    [string]$Domain = 'pb04-datn.test',
    [string]$Log = '/tmp/pb04-atomic-run.log'
)
$ErrorActionPreference = 'Stop'
$guid = '7ff17b4b-7cbf-48b7-97ab-0704d7c8d486'
$folder = '/home/kali/AtomicRedTeam/atomics'
$inputArgs = @{ domain = $Domain }
try {
    Import-Module Invoke-AtomicRedTeam -ErrorAction Stop
    "start_utc=$((Get-Date).ToUniversalTime().ToString('o'))" | Set-Content $Log
    Invoke-AtomicTest T1071.004 -TestGuids $guid -PathToAtomicsFolder $folder -InputArgs $inputArgs -CheckPrereqs -Confirm:$false *>&1 |
        Out-String | Add-Content $Log
    Invoke-AtomicTest T1071.004 -TestGuids $guid -PathToAtomicsFolder $folder -InputArgs $inputArgs -Confirm:$false *>&1 |
        Out-String | Add-Content $Log
    "end_utc=$((Get-Date).ToUniversalTime().ToString('o'))" | Add-Content $Log
} catch {
    "ERROR: $($_.Exception.Message)" | Add-Content $Log
    exit 1
}
