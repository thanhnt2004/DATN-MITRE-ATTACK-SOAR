param(
    [string]$ShuffleBaseUrl = 'http://18.139.50.205:3001',
    [string]$CredentialFile = 'D:\DATN\private\2026-10-15_credentials-ec2-elk-shuffle-report.md',
    [string]$SourceWorkflowId = '2c92993a-4901-479c-a677-44bf2851186f',
    [string]$WorkflowIdFile = 'D:\DATN\private\t1105-shuffle-workflow-id.txt'
)

$ErrorActionPreference = 'Stop'
$credentialText = Get-Content -Raw -LiteralPath $CredentialFile
$passwordMatch = [regex]::Match($credentialText, 'Mật khẩu Shuffle UI.*?~~~~text\r?\n(?<password>.*?)\r?\n~~~~', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$usernameMatch = [regex]::Match($credentialText, '\| Shuffle UI \| (?<username>[^|]+) \|')
if (-not $passwordMatch.Success -or -not $usernameMatch.Success) { throw 'Shuffle credential not found' }
$loginBody = @{ username = $usernameMatch.Groups['username'].Value.Trim(); password = $passwordMatch.Groups['password'].Value.Trim() } | ConvertTo-Json -Compress
$null = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/login" -Method Post -ContentType 'application/json' -Body $loginBody -SessionVariable session

$name = 'T1105 Lab Download Investigation'
$template = @'
[T1105] Lab Download Investigation
Host: $exec.host
User: $exec.user
Source: $exec.remote_ip
File: $exec.target_display
Process: $exec.process_display
Process GUID: $exec.process_guid
Decision: $exec.decision
Test ID: $exec.test_id
Status: $exec.status
'@

$targetId = if (Test-Path -LiteralPath $WorkflowIdFile) { (Get-Content -Raw -LiteralPath $WorkflowIdFile).Trim() } else { '' }
if ($targetId) {
    $target = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$targetId" -WebSession $session
    if ($target.name -ne $name) { throw 'Saved T1105 workflow ID refers to another workflow' }
    $message = ($target.actions[0].parameters | Where-Object name -eq 'body' | Select-Object -First 1).value_replace | Where-Object key -eq '${message}' | Select-Object -First 1
    if (-not $message) { throw 'T1105 Telegram template not found' }
    $message.value = $template
    $saved = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$targetId" -Method Put -ContentType 'application/json' -Body ($target | ConvertTo-Json -Depth 100 -Compress) -WebSession $session
    [pscustomobject]@{ workflow_id = $targetId; trigger_id = $target.triggers[0].id; save_success = $saved.success; existing = $true } | ConvertTo-Json -Compress
    exit 0
}

$source = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$SourceWorkflowId" -WebSession $session
$createBody = @{ name = $name; description = 'DATN T1105 lab download; constrained quarantine via host responder.' } | ConvertTo-Json -Compress
$target = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows" -Method Post -ContentType 'application/json' -Body $createBody -WebSession $session
Set-Content -LiteralPath $WorkflowIdFile -Value $target.id -NoNewline
$action = $source.actions[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$trigger = $source.triggers[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$branch = $source.branches[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$action.id = [guid]::NewGuid().ToString()
$action.label = 'Telegram_T1105_Download_Alert'
$action.isStartNode = $true
$message = ($action.parameters | Where-Object name -eq 'body' | Select-Object -First 1).value_replace | Where-Object key -eq '${message}' | Select-Object -First 1
if (-not $message) { throw 'Source Telegram template not found' }
$message.value = $template
$trigger.id = [guid]::NewGuid().ToString()
$trigger.label = 'Webhook_T1105_Download'
$trigger.status = 'running'
$trigger.environment = 'onprem'
($trigger.parameters | Where-Object name -eq 'url' | Select-Object -First 1).value = "$ShuffleBaseUrl/api/v1/hooks/webhook_$($trigger.id)"
$branch.id = [guid]::NewGuid().ToString()
$branch.source_id = $trigger.id
$branch.destination_id = $action.id
$branch.has_errors = $false
$target.name = $name
$target.actions = @($action)
$target.triggers = @($trigger)
$target.branches = @($branch)
$target.start = $action.id
$target.is_valid = $true
$saved = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$($target.id)" -Method Put -ContentType 'application/json' -Body ($target | ConvertTo-Json -Depth 100 -Compress) -WebSession $session
$hookBody = @{ name = $trigger.label; type = 'webhook'; id = $trigger.id; workflow = $target.id; start = $action.id; environment = 'onprem'; auth = '' } | ConvertTo-Json -Compress
$hook = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/hooks" -Method Post -ContentType 'application/json' -Body $hookBody -WebSession $session
if (-not $saved.success -or -not $hook.success) { throw 'PB04 workflow or hook creation failed' }
[pscustomobject]@{ workflow_id = $target.id; trigger_id = $trigger.id; save_success = $saved.success; hook_success = $hook.success; existing = $false } | ConvertTo-Json -Compress
