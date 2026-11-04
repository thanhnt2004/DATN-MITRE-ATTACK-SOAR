param([string]$Stage = 'C:\Windows\Temp\datn-t1059')
$ErrorActionPreference = 'Stop'
$report = Join-Path $Stage 'install.log'
Start-Transcript -Path $report -Force | Out-Null
try {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator rights required' }
    if (Get-Service -Name Sysmon64,Sysmon -ErrorAction SilentlyContinue) { throw 'Sysmon already installed; inspect existing configuration before changing it' }
    if (Get-Service -Name winlogbeat -ErrorAction SilentlyContinue) { throw 'Winlogbeat already installed; merge configuration manually' }
    $signature = Get-AuthenticodeSignature (Join-Path $Stage 'Sysmon64.exe')
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') { throw 'Sysmon signature validation failed' }
    & (Join-Path $Stage 'Sysmon64.exe') -accepteula -i
    if ($LASTEXITCODE -ne 0) { throw "Sysmon installation failed: $LASTEXITCODE" }
    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name EnableScriptBlockLogging -Value 1 -PropertyType DWord -Force | Out-Null
    $expanded = Join-Path $Stage 'winlogbeat-expanded'
    Expand-Archive -LiteralPath (Join-Path $Stage 'winlogbeat.zip') -DestinationPath $expanded -Force
    $package = Get-ChildItem -LiteralPath $expanded -Directory | Select-Object -First 1
    $target = 'C:\Program Files\Winlogbeat'
    if (Test-Path $target) { throw 'Winlogbeat directory already exists; inspect before changing it' }
    Move-Item -LiteralPath $package.FullName -Destination $target
    New-Item -Path "$target\certs" -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Stage 'ca.crt') -Destination "$target\certs\ca.crt"
    Copy-Item -LiteralPath (Join-Path $Stage 'winlogbeat.yml') -Destination "$target\winlogbeat.yml" -Force
    & "$target\winlogbeat.exe" test config -c "$target\winlogbeat.yml" -e
    if ($LASTEXITCODE -ne 0) { throw 'Winlogbeat config test failed' }
    & "$target\winlogbeat.exe" test output -c "$target\winlogbeat.yml" -e
    if ($LASTEXITCODE -ne 0) { throw 'Winlogbeat output test failed' }
    & "$target\install-service-winlogbeat.ps1"
    Start-Service winlogbeat
    Get-Service Sysmon64,winlogbeat | Format-Table Name,Status,StartType -AutoSize
    'INSTALL_STATUS=SUCCESS'
} catch {
    "INSTALL_STATUS=FAILED: $($_.Exception.Message)"
    exit 1
} finally {
    Stop-Transcript | Out-Null
}
