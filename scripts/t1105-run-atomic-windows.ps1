param([string]$Stage = 'C:\Windows\Temp\datn-t1105')
$ErrorActionPreference = 'Stop'
Start-Transcript -Path (Join-Path $Stage 'atomic-run.log') -Force | Out-Null
try {
    $env:PSModulePath = 'C:\Windows\Temp\datn-t1059\modules;' + $env:PSModulePath
    Import-Module Invoke-AtomicRedTeam -ErrorAction Stop
    $folder = Join-Path $Stage 'atomics'
    New-Item -ItemType Directory -Path (Join-Path $folder 'T1105') -Force | Out-Null
    New-Item -ItemType Directory -Path 'C:\DATN-T1105\incoming' -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Stage 'T1105.yaml') -Destination (Join-Path $folder 'T1105\T1105.yaml') -Force
    $args = @{ remote_file = 'http://192.168.10.102:8088/t1105-lab-sample.txt'; destination_path = 'C:\DATN-T1105\incoming\t1105-lab-sample.txt' }
    # DATN lab extension: leaves the downloader alive briefly for Event 3 correlation.
    $guid = '1a4cb27d-4834-4c6a-86e0-01f8b0f6cbe7'
    if (Test-Path -LiteralPath $args.destination_path) {
        $existing = (Get-FileHash -Algorithm SHA256 -LiteralPath $args.destination_path).Hash
        if ($existing -ne '613DBDF3F2E76FF5773E8A5C6D09D6278A907F985108E33DB7C62E772635A754') { throw 'Existing file is not the known lab sample' }
        Remove-Item -LiteralPath $args.destination_path
    }
    "ATOMIC_START_UTC=$([DateTime]::UtcNow.ToString('o'))"
    Invoke-AtomicTest T1105 -TestGuids $guid -PathToAtomicsFolder $folder -InputArgs $args -CheckPrereqs -Confirm:$false
    Invoke-AtomicTest T1105 -TestGuids $guid -PathToAtomicsFolder $folder -InputArgs $args -Confirm:$false
    $path = $args.destination_path
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Downloaded file does not exist' }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    "DOWNLOADED_SHA256=$hash"
    "ATOMIC_END_UTC=$([DateTime]::UtcNow.ToString('o'))"
    'WRAPPER_STATUS=COMPLETED'
} catch {
    "WRAPPER_STATUS=FAILED: $($_.Exception.Message)"
    exit 1
} finally { Stop-Transcript | Out-Null }
