param([switch]$Once)
$ErrorActionPreference = 'Stop'
$createdNew = $false
$mutex = [Threading.Mutex]::new($true, 'Local\DATN-T1105-Responder', [ref]$createdNew)
if (-not $createdNew) { throw 'T1105 responder already running in this Windows session' }
$base = 'http://18.139.50.205:3001'
$workflow = 'c6af5a23-ec06-4792-bffa-b96661e3e4c0'
$hook = 'http://18.139.50.205:3001/api/v1/hooks/webhook_42b7915c-a4c0-4a6f-b9dc-14642d70a1b9'
$vmx = 'D:\tool\Windows 10 x64\Windows 10 x64.vmx'
$vmrun = 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe'
$private = 'D:\DATN\private'
$log = 'D:\DATN\work\t1105-responder.log'
$statePath = Join-Path $private 't1105-responder-state.json'
$text = Get-Content -Raw -LiteralPath (Join-Path $private '2026-10-15_credentials-ec2-elk-shuffle-report.md')
$p = [regex]::Match($text, 'Mật khẩu Shuffle UI.*?~~~~text\r?\n(?<password>.*?)\r?\n~~~~', [Text.RegularExpressions.RegexOptions]::Singleline)
$u = [regex]::Match($text, '\| Shuffle UI \| (?<username>[^|]+) \|')
if (-not $p.Success -or -not $u.Success) { throw 'Shuffle credential missing' }
$guest = Import-Clixml -LiteralPath (Join-Path $private 't1105-windows-guest-credential.xml')
$body = @{username=$u.Groups['username'].Value.Trim(); password=$p.Groups['password'].Value.Trim()} | ConvertTo-Json -Compress
$session = $null
$state = @{}
if (Test-Path $statePath) { (Get-Content -Raw $statePath | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value } }
do {
  try {
    if (-not $session) {
      $null = Invoke-RestMethod -Uri "$base/api/v1/login" -Method Post -ContentType 'application/json' -Body $body -SessionVariable session
    }
    $result = Invoke-RestMethod -Uri "$base/api/v1/workflows/$workflow/executions" -WebSession $session
    $rows = if ($result -is [array]) { $result } elseif ($result.data) { @($result.data) } elseif ($result.executions) { @($result.executions) } else { @($result) }
    foreach ($run in $rows) {
      if ($run.status -ne 'FINISHED' -or $state.ContainsKey([string]$run.execution_id) -or -not @($run.results | Where-Object { $_.status -eq 'SUCCESS' }).Count) { continue }
      $arg = if ($run.execution_argument -is [string]) { $run.execution_argument | ConvertFrom-Json } else { $run.execution_argument }
      if ($arg.test_id -ne 'T1105-LAB-AUTO' -or $arg.decision -ne 'LAB_AUTO_QUARANTINE' -or $arg.status -ne 'DETECTED_PENDING_QUARANTINE') { continue }
      if ($arg.host -ne 'DESKTOP-2FV6M9C' -or $arg.remote_ip -ne '192.168.10.102' -or $arg.target_display -ne 'C:/DATN-T1105/incoming/t1105-lab-sample.txt' -or $arg.expected_sha256 -ne '613DBDF3F2E76FF5773E8A5C6D09D6278A907F985108E33DB7C62E772635A754') { continue }
      # ConvertFrom-Json may already parse ISO timestamps to DateTime (UTC).
      # Parsing its culture-formatted string would silently assume local time.
      $when = if ($arg.event_time -is [DateTime]) { [DateTimeOffset]$arg.event_time } else { [DateTimeOffset]::Parse([string]$arg.event_time) }
      if ([Math]::Abs(([DateTimeOffset]::UtcNow - $when).TotalMinutes) -gt 10) { continue }
      $null = & $vmrun -T ws -gu $guest.UserName -gp ($guest.GetNetworkCredential().Password) runProgramInGuest $vmx 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File 'C:\Windows\Temp\datn-t1105\quarantine.ps1' -Action Quarantine
      if ($LASTEXITCODE -ne 0) { throw "Guest quarantine failed for execution $($run.execution_id)" }
      $local = 'D:\DATN\work\t1105-quarantine-result.json'
      $null = & $vmrun -T ws -gu $guest.UserName -gp ($guest.GetNetworkCredential().Password) CopyFileFromGuestToHost $vmx 'C:\Windows\Temp\datn-t1105\response.json' $local
      if ($LASTEXITCODE -ne 0) { throw 'Could not retrieve guest response' }
      $response = Get-Content -Raw -LiteralPath $local | ConvertFrom-Json
      if ($response.status -ne 'SUCCESS' -or $response.action -ne 'Quarantine' -or $response.source_exists -or -not $response.quarantine_exists) { throw 'Quarantine verification did not pass' }
      $state[[string]$run.execution_id] = [DateTime]::UtcNow.ToString('o')
      $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
      "$(Get-Date -Format o) execution=$($run.execution_id) action=quarantine status=SUCCESS sha256=$($response.sha256)" | Add-Content -LiteralPath $log
      $reply = @{host=$arg.host;user=$arg.user;remote_ip=$arg.remote_ip;target_display=$arg.target_display;process_display=$arg.process_display;process_guid=$arg.process_guid;decision='QUARANTINE_VERIFIED';test_id='T1105-LAB-RESULT';status='QUARANTINED'} | ConvertTo-Json -Compress
      $null = Invoke-RestMethod -Uri $hook -Method Post -ContentType 'application/json' -Body $reply
    }
  } catch { $session = $null; "$(Get-Date -Format o) ERROR $($_.Exception.Message)" | Add-Content -LiteralPath $log }
  if (-not $Once) { Start-Sleep -Seconds 15 }
} while (-not $Once)
