param([string]$Stage = 'C:\Windows\Temp\datn-t1059')
$ErrorActionPreference = 'Stop'
Start-Transcript -Path (Join-Path $Stage 'atomic-run.log') -Force | Out-Null
try {
    $modules = Join-Path $Stage 'modules'
    Expand-Archive -LiteralPath (Join-Path $Stage 'modules.zip') -DestinationPath $modules -Force
    $env:PSModulePath = "$modules;$env:PSModulePath"
    Import-Module Invoke-AtomicRedTeam -ErrorAction Stop
    $folder = Join-Path $Stage 'atomics'
    New-Item -ItemType Directory -Path (Join-Path $folder 'T1059.001') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Stage 'T1059.001.yaml') -Destination (Join-Path $folder 'T1059.001\T1059.001.yaml') -Force
    $guid = 'a538de64-1c74-46ed-aa60-b995ed302598'
    "ATOMIC_START_UTC=$([DateTime]::UtcNow.ToString('o'))"
    Invoke-AtomicTest T1059.001 -TestGuids $guid -PathToAtomicsFolder $folder -CheckPrereqs -Confirm:$false
    Invoke-AtomicTest T1059.001 -TestGuids $guid -PathToAtomicsFolder $folder -Confirm:$false
    "ATOMIC_END_UTC=$([DateTime]::UtcNow.ToString('o'))"
    'WRAPPER_STATUS=COMPLETED'
} catch {
    "WRAPPER_STATUS=FAILED: $($_.Exception.Message)"
    exit 1
} finally {
    Stop-Transcript | Out-Null
}
