param(
    [string]$ShuffleBaseUrl = 'http://18.139.50.205:3001',
    [string]$CredentialFile = 'D:\DATN\private\2026-10-15_credentials-ec2-elk-shuffle-report.md',
    [string]$SourceWorkflowId = 'ea1c4941-8b6a-4069-b686-095a050aa585',
    [string]$TargetWorkflowId = '2c92993a-4901-479c-a677-44bf2851186f'
)

$ErrorActionPreference = 'Stop'
$credentialText = Get-Content -Raw -LiteralPath $CredentialFile
$passwordMatch = [regex]::Match($credentialText, 'Mật khẩu Shuffle UI.*?~~~~text\r?\n(?<password>.*?)\r?\n~~~~', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$usernameMatch = [regex]::Match($credentialText, '\| Shuffle UI \| (?<username>[^|]+) \|')
if (-not $passwordMatch.Success -or -not $usernameMatch.Success) { throw 'Shuffle credential was not found in the local inventory.' }
$body = @{ username = $usernameMatch.Groups['username'].Value.Trim(); password = $passwordMatch.Groups['password'].Value.Trim() } | ConvertTo-Json -Compress
$null = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/login" -Method Post -ContentType 'application/json' -Body $body -SessionVariable session

$name = 'PB01 T1110.003 Password Spraying - Notify Only'
$messageTemplate = @'
[PB01] T1110.003 Password Spraying
Attack source: $exec.attack_source
Atomic GUID: $exec.atomic_guid
Source IP: $exec.source_ip
Accounts: $exec.distinct_user_count
Failed logons: $exec.failed_authentication_count
Hosts: $exec.hosts_text
Test ID: $exec.test_id
Status: $exec.status
'@
$target = $null
if ($TargetWorkflowId) {
    try {
        $target = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$TargetWorkflowId" -WebSession $session
    } catch {
        if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
    }
}
if (-not $target -and $TargetWorkflowId) {
    throw 'Target workflow ID was not found. Pass -TargetWorkflowId "" only when intentionally creating PB01 in a new organization.'
}
if ($target) {
    if ($target.name -ne $name) { throw 'Target workflow ID refers to a different workflow.' }
    $existingMessage = ($target.actions[0].parameters | Where-Object name -eq 'body' | Select-Object -First 1).value_replace | Where-Object key -eq '${message}' | Select-Object -First 1
    if (-not $existingMessage) { throw 'Existing workflow has no Telegram message template.' }
    $existingMessage.value = $messageTemplate
    $saved = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$($target.id)" -Method Put -ContentType 'application/json' -Body ($target | ConvertTo-Json -Depth 100 -Compress) -WebSession $session
    [pscustomobject]@{ workflow_id = $target.id; workflow_name = $target.name; trigger_id = $target.triggers[0].id; save_success = $saved.success; existing = $true } | ConvertTo-Json -Compress
    exit 0
}

$source = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$SourceWorkflowId" -WebSession $session
$createBody = @{ name = $name; description = 'Lab PB01 T1110.003; detector qualifies five distinct users in five minutes; notification only.' } | ConvertTo-Json -Compress
$target = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows" -Method Post -ContentType 'application/json' -Body $createBody -WebSession $session
$action = $source.actions[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$trigger = $source.triggers[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$branch = $source.branches[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$action.id = [guid]::NewGuid().ToString()
$action.label = 'Telegram_PB01_Password_Spraying'
$action.isStartNode = $true
$message = ($action.parameters | Where-Object name -eq 'body' | Select-Object -First 1).value_replace | Where-Object key -eq '${message}' | Select-Object -First 1
if (-not $message) { throw 'Telegram message template was not found in source workflow.' }
$message.value = $messageTemplate
$trigger.id = [guid]::NewGuid().ToString()
$trigger.label = 'Webhook_PB01_Password_Spraying'
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
[pscustomobject]@{ workflow_id = $target.id; workflow_name = $target.name; trigger_id = $trigger.id; save_success = $saved.success; hook_success = $hook.success; existing = $false } | ConvertTo-Json -Compress
