$ErrorActionPreference = 'Stop'
try {
    if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Default
    }
    Install-Module -Name invoke-atomicredteam,powershell-yaml -Scope CurrentUser -Force -AcceptLicense -ErrorAction Stop
    Import-Module invoke-atomicredteam -ErrorAction Stop
    Get-Module invoke-atomicredteam,powershell-yaml -ListAvailable |
        Select-Object Name, Version, Path | Format-Table -AutoSize | Out-String |
        Set-Content /tmp/pb01-module-install.log
} catch {
    "ERROR: $($_.Exception.Message)" | Set-Content /tmp/pb01-module-install.log
    exit 1
}
