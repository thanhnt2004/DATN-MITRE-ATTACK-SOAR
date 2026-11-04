param(
    [string]$ShuffleBaseUrl = 'http://18.139.50.205:3001',
    [string]$CredentialFile = 'D:\DATN\private\2026-10-15_credentials-ec2-elk-shuffle-report.md',
    [string]$WorkflowId = '2c92993a-4901-479c-a677-44bf2851186f',
    [string]$TestId = 'DATN-PB01-ATOMIC-20261103-071431Z',
    [switch]$InspectMessage
)
$ErrorActionPreference = 'Stop'
$credentialText = Get-Content -Raw -LiteralPath $CredentialFile
$passwordMatch = [regex]::Match($credentialText, 'Mật khẩu Shuffle UI.*?~~~~text\r?\n(?<password>.*?)\r?\n~~~~', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$usernameMatch = [regex]::Match($credentialText, '\| Shuffle UI \| (?<username>[^|]+) \|')
if (-not $passwordMatch.Success -or -not $usernameMatch.Success) { throw 'Shuffle credential not found' }
$body = @{ username = $usernameMatch.Groups['username'].Value.Trim(); password = $passwordMatch.Groups['password'].Value.Trim() } | ConvertTo-Json -Compress
$null = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/login" -Method Post -ContentType 'application/json' -Body $body -SessionVariable session
$result = Invoke-RestMethod -Uri "$ShuffleBaseUrl/api/v1/workflows/$WorkflowId/executions" -WebSession $session
$rows = if ($result -is [array]) { $result } elseif ($result.data) { @($result.data) } elseif ($result.executions) { @($result.executions) } else { @($result) }
$matches = @($rows | Where-Object { ($_.execution_argument | ConvertTo-Json -Depth 20 -Compress) -like "*$TestId*" })
foreach ($run in $matches) {
    if ($InspectMessage -and $run.results.Count -gt 0) {
        $actionResult = $run.results[0].result
        $decoded = try { $actionResult | ConvertFrom-Json -ErrorAction Stop } catch { $null }
        $telegramBody = if($decoded -and $decoded.body -is [string]) { try { $decoded.body | ConvertFrom-Json -ErrorAction Stop } catch { $null } } elseif($decoded) { $decoded.body } else { $null }
        [pscustomobject]@{
            telegram_ok = if($telegramBody){$telegramBody.ok}else{$false}
            telegram_text = if($telegramBody -and $telegramBody.result){$telegramBody.result.text}else{''}
        } | ConvertTo-Json -Compress
    }
    [pscustomobject]@{
        execution_id = $run.execution_id
        workflow_id = $run.workflow_id
        status = $run.status
        started_at = $run.started_at
        completed_at = $run.completed_at
        action_statuses = @($run.results | ForEach-Object { $_.status })
        telegram_success = [bool](($run.results | ConvertTo-Json -Depth 20 -Compress) -match '"ok"\s*:\s*true|\\"ok\\"\s*:\s*true')
        test_id = $TestId
    } | ConvertTo-Json -Depth 8 -Compress
}
if (-not $matches) {
    "no_matching_execution; returned_rows=$($rows.Count)"
}
