param([ValidateSet('Quarantine','Restore')][string]$Action = 'Quarantine')
$ErrorActionPreference = 'Stop'
$source = 'C:\DATN-T1105\incoming\t1105-lab-sample.txt'
$qdir = 'C:\ProgramData\DATN-T1105\Quarantine'
$target = Join-Path $qdir 't1105-lab-sample.txt.quarantined'
$metadata = Join-Path $qdir 't1105-lab-sample.metadata.json'
$expected = '613DBDF3F2E76FF5773E8A5C6D09D6278A907F985108E33DB7C62E772635A754'
$log = 'C:\Windows\Temp\datn-t1105\response.json'
try {
    foreach ($dir in @('C:\DATN-T1105', 'C:\DATN-T1105\incoming', 'C:\ProgramData')) {
        $item = Get-Item -LiteralPath $dir -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point rejected: $dir" }
    }
    if ($Action -eq 'Quarantine') {
        if (Test-Path -LiteralPath $target) { throw 'Quarantine target exists; refusing overwrite' }
        $item = Get-Item -LiteralPath $source -Force
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Source is not a regular file' }
        $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if ($hash -ne $expected) { throw 'Source SHA256 does not match approved lab sample' }
        New-Item -ItemType Directory -Path $qdir -Force | Out-Null
        foreach ($dir in @('C:\ProgramData\DATN-T1105', $qdir)) {
            if ((Get-Item -LiteralPath $dir -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Quarantine reparse point rejected' }
        }
        & icacls.exe $qdir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Cannot restrict quarantine directory ACL' }
        $sddl = (Get-Acl -LiteralPath $source).Sddl
        Move-Item -LiteralPath $source -Destination $target
        try {
            & icacls.exe $target /inheritance:r /grant:r '*S-1-5-32-544:F' '*S-1-5-18:F' | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Cannot restrict quarantine file ACL' }
            $after = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            if ($after -ne $expected) { throw 'Quarantine hash mismatch' }
            @{source=$source; sha256=$hash; original_sddl=$sddl; quarantined_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath $metadata
        } catch {
            if ((Test-Path -LiteralPath $target) -and !(Test-Path -LiteralPath $source)) { Move-Item -LiteralPath $target -Destination $source }
            throw
        }
        $result = @{action='Quarantine'; status='SUCCESS'; source_exists=(Test-Path -LiteralPath $source); quarantine_exists=(Test-Path -LiteralPath $target); sha256=$after; time_utc=[DateTime]::UtcNow.ToString('o')}
    } else {
        if (Test-Path -LiteralPath $source) { throw 'Original path already exists; refusing overwrite' }
        $meta = Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json
        if ($meta.source -ne $source -or $meta.sha256 -ne $expected) { throw 'Metadata does not match lab sample' }
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $expected) { throw 'Quarantined SHA256 mismatch' }
        Move-Item -LiteralPath $target -Destination $source
        $acl = Get-Acl -LiteralPath $source
        $acl.SetSecurityDescriptorSddlForm($meta.original_sddl)
        Set-Acl -LiteralPath $source -AclObject $acl
        $after = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $result = @{action='Restore'; status='SUCCESS'; source_exists=(Test-Path -LiteralPath $source); quarantine_exists=(Test-Path -LiteralPath $target); sha256=$after; time_utc=[DateTime]::UtcNow.ToString('o')}
    }
    $result | ConvertTo-Json | Set-Content -LiteralPath $log -Encoding UTF8
    $result | ConvertTo-Json -Compress
} catch {
    @{action=$Action; status='FAILED'; reason=$_.Exception.Message; time_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $log -Encoding UTF8
    throw
}
