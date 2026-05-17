param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json",
    [int] $PollSeconds = 75
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "public-tester-gateway-e2e" | Out-Null
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$runDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/public-tester-gateway-e2e")
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/state.json")
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$gatewayStatePath = Join-Path $runDir "state.json"
$gatewayNodeDir = Join-Path $runDir "node"
$gatewayWalletMetadataPath = Join-Path $runDir "wallets\flowchain-public-tester-gateway-public-metadata.json"

$envNames = @(
    "FLOWCHAIN_OWNER_ENV_FILE",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
    "FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH",
    "FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH"
)
$originalEnv = @{}
foreach ($name in $envNames) {
    $originalEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

$serverProcess = $null
$stdoutPath = Join-Path $runDir "control-plane.stdout.log"
$stderrPath = Join-Path $runDir "control-plane.stderr.log"
$runId = ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff") + "-$PID")
$allowedOrigin = "https://flowchain-public-tester-gateway-e2e.example"
$testerToken = "flowchain-public-tester-gateway-e2e-$runId"
$headers = @{
    Origin = $allowedOrigin
    Authorization = "Bearer $testerToken"
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string] $Value)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-FreeLocalPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Invoke-GatewayJson {
    param(
        [Parameter(Mandatory = $true)][string] $BaseUrl,
        [Parameter(Mandatory = $true)][string] $Path,
        [string] $Method = "GET",
        [AllowNull()][object] $Body = $null,
        [hashtable] $Headers = @{}
    )

    $args = @{
        Uri = "$($BaseUrl.TrimEnd('/'))$Path"
        Method = $Method
        Headers = $Headers
        TimeoutSec = 120
    }
    if ($null -ne $Body) {
        $args.ContentType = "application/json"
        $args.Body = $Body | ConvertTo-Json -Depth 20
    }
    return Invoke-RestMethod @args
}

function Invoke-GatewayHttp {
    param(
        [Parameter(Mandatory = $true)][string] $BaseUrl,
        [Parameter(Mandatory = $true)][string] $Path,
        [string] $Method = "GET",
        [AllowNull()][object] $Body = $null,
        [hashtable] $Headers = @{}
    )

    $args = @{
        Uri = "$($BaseUrl.TrimEnd('/'))$Path"
        Method = $Method
        Headers = $Headers
        TimeoutSec = 120
        UseBasicParsing = $true
    }
    if ($null -ne $Body) {
        $args.ContentType = "application/json"
        $args.Body = $Body | ConvertTo-Json -Depth 20
    }
    try {
        $response = Invoke-WebRequest @args
        return [ordered]@{
            statusCode = [int] $response.StatusCode
            body = if ([string]::IsNullOrWhiteSpace("$($response.Content)")) { $null } else { $response.Content | ConvertFrom-Json }
        }
    }
    catch {
        $response = $null
        if ($_.Exception.PSObject.Properties.Name -contains "Response") {
            $response = $_.Exception.Response
        }
        $statusCode = 0
        $bodyText = ""
        if ($null -ne $response) {
            $statusCode = [int] $response.StatusCode
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = [System.IO.StreamReader]::new($stream)
                try {
                    $bodyText = $reader.ReadToEnd()
                }
                finally {
                    $reader.Dispose()
                }
            }
        }
        return [ordered]@{
            statusCode = $statusCode
            body = if ([string]::IsNullOrWhiteSpace($bodyText)) { $null } else { $bodyText | ConvertFrom-Json }
        }
    }
}

function Invoke-GatewayRpc {
    param(
        [Parameter(Mandatory = $true)][string] $BaseUrl,
        [Parameter(Mandatory = $true)][string] $Method,
        [object] $Params = @{}
    )

    $response = Invoke-GatewayJson -BaseUrl $BaseUrl -Path "/rpc" -Method "POST" -Body ([ordered]@{
        jsonrpc = "2.0"
        id = $Method
        method = $Method
        params = $Params
    })
    if ($response.PSObject.Properties.Name -contains "error" -and $null -ne $response.error) {
        throw "RPC $Method failed: $($response.error.message)"
    }
    return $response.result
}

function Invoke-CargoJson {
    param([Parameter(Mandatory = $true)][string[]] $ArgumentList)

    $output = & cargo @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "cargo $($ArgumentList -join ' ') failed with exit code $LASTEXITCODE"
    }
    return $output | ConvertFrom-Json
}

function Wait-GatewayHealth {
    param(
        [Parameter(Mandatory = $true)][string] $BaseUrl,
        [int] $TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-GatewayJson -BaseUrl $BaseUrl -Path "/health"
            if ($null -ne $response -and $response.schema -eq "flowmemory.control_plane.health.v0") {
                return
            }
            $lastError = "unexpected health schema"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Temporary tester gateway control-plane did not become healthy. Last status: $lastError"
}

function Wait-GatewayBalanceEquals {
    param(
        [Parameter(Mandatory = $true)][string] $BaseUrl,
        [Parameter(Mandatory = $true)][string] $AccountId,
        [Parameter(Mandatory = $true)][int64] $Amount
    )

    $deadline = (Get-Date).AddSeconds($PollSeconds)
    $lastError = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $balance = Invoke-GatewayRpc -BaseUrl $BaseUrl -Method "balance_get" -Params @{ accountId = $AccountId }
            $actual = [int64] $balance.amount
            if ($actual -eq $Amount) {
                return $balance
            }
            $lastError = "balance=$actual expected=$Amount"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Seconds 1
    }
    throw "Timed out waiting for $AccountId balance = $Amount. Last status: $lastError"
}

try {
    Copy-Item -LiteralPath $stateFullPath -Destination $gatewayStatePath -Force
    New-Item -ItemType Directory -Force -Path $gatewayNodeDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $gatewayWalletMetadataPath) | Out-Null

    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $null, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_ALLOWED_ORIGINS", $allowedOrigin, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "120", "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_TESTER_WRITE_ENABLED", "true", "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256", (Get-Sha256Hex -Value $testerToken), "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_TESTER_MAX_SEND_UNITS", "2", "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH", $gatewayStatePath, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH", $gatewayWalletMetadataPath, "Process")
    Remove-Item Env:\FLOWCHAIN_OWNER_ENV_FILE -ErrorAction SilentlyContinue
    $env:FLOWCHAIN_RPC_ALLOWED_ORIGINS = $allowedOrigin
    $env:FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE = "120"
    $env:FLOWCHAIN_TESTER_WRITE_ENABLED = "true"
    $env:FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 = Get-Sha256Hex -Value $testerToken
    $env:FLOWCHAIN_TESTER_MAX_SEND_UNITS = "10"
    $env:FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH = $gatewayStatePath
    $env:FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH = $gatewayWalletMetadataPath

    $port = Get-FreeLocalPort
    $baseUrl = "http://127.0.0.1:$port"
    $serverScript = Join-Path $repoRoot "services/control-plane/src/server.ts"
    $serverProcess = Start-Process -FilePath "node" `
        -ArgumentList @($serverScript, "--host", "127.0.0.1", "--port", "$port") `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru
    Wait-GatewayHealth -BaseUrl $baseUrl

    $status = Invoke-GatewayJson -BaseUrl $baseUrl -Path "/tester/status" -Headers @{ Origin = $allowedOrigin }
    if ($status.schema -ne "flowmemory.control_plane.tester_write_status.v0" -or $status.configured -ne $true -or $status.maxSendUnits -ne "10") {
        throw "Tester gateway status did not report configured=true with the expected cap."
    }

    $walletA = Invoke-GatewayJson -BaseUrl $baseUrl -Path "/tester/wallets/create" -Method "POST" -Headers $headers -Body ([ordered]@{
        label = "public-gateway-$runId-a"
        password = "public-tester-gateway-$runId-a"
        chainId = "31337"
        replace = $true
    })
    $walletB = Invoke-GatewayJson -BaseUrl $baseUrl -Path "/tester/wallets/create" -Method "POST" -Headers $headers -Body ([ordered]@{
        label = "public-gateway-$runId-b"
        password = "public-tester-gateway-$runId-b"
        chainId = "31337"
        replace = $true
    })
    if ($walletA.schema -ne "flowmemory.control_plane.tester_wallet_create_result.v0" -or $walletB.schema -ne "flowmemory.control_plane.tester_wallet_create_result.v0") {
        throw "Tester wallet create route did not return tester wallet create schemas."
    }
    if ($walletA.secretMaterialReturned -ne $false -or $walletB.secretMaterialReturned -ne $false) {
        throw "Tester wallet create route returned secret material."
    }

    $accountA = "$($walletA.account.accountId)"
    $accountB = "$($walletB.account.accountId)"
    $faucetResponses = @()
    foreach ($account in @($accountA, $accountB)) {
        $faucetResponses += Invoke-GatewayJson -BaseUrl $baseUrl -Path "/tester/faucet" -Method "POST" -Headers $headers -Body ([ordered]@{
            accountId = $account
            amountUnits = "10"
            reason = "public-tester-gateway-e2e"
        })
    }
    if (@($faucetResponses | Where-Object { $_.schema -ne "flowmemory.control_plane.tester_faucet_result.v0" -or $_.accepted -ne $true }).Count -gt 0) {
        throw "Tester faucet route did not accept the capped funding requests."
    }

    [void] (Wait-GatewayBalanceEquals -BaseUrl $baseUrl -AccountId $accountA -Amount 10)
    [void] (Wait-GatewayBalanceEquals -BaseUrl $baseUrl -AccountId $accountB -Amount 10)

    $send = Invoke-GatewayJson -BaseUrl $baseUrl -Path "/tester/wallets/send" -Method "POST" -Headers $headers -Body ([ordered]@{
        fromAccountId = $accountA
        toAccountId = $accountB
        amountUnits = "1"
        memo = "public-tester-gateway-e2e"
        createRecipient = $false
    })
    if ($send.schema -ne "flowmemory.control_plane.tester_wallet_send_result.v0" -or $send.accepted -ne $true) {
        throw "Tester wallet send route did not accept the capped transfer."
    }

    [void] (Wait-GatewayBalanceEquals -BaseUrl $baseUrl -AccountId $accountA -Amount 9)
    [void] (Wait-GatewayBalanceEquals -BaseUrl $baseUrl -AccountId $accountB -Amount 11)

    $overCap = Invoke-GatewayHttp -BaseUrl $baseUrl -Path "/tester/wallets/send" -Method "POST" -Headers $headers -Body ([ordered]@{
        fromAccountId = $accountA
        toAccountId = $accountB
        amountUnits = "11"
        memo = "public-tester-gateway-e2e-over-cap"
        createRecipient = $false
    })
    $overCapBody = $overCap.body
    if ($overCap.statusCode -ne 400 -or $overCapBody.schema -ne "flowmemory.control_plane.tester_wallet_send_error.v0" -or $overCapBody.noSecrets -ne $true) {
        throw "Tester wallet send cap did not fail closed with a public-safe error."
    }

    $report = [ordered]@{
        schema = "flowchain.public_tester_gateway_e2e_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = "passed"
        localOnly = $true
        originRestricted = $true
        testerGatewayConfigured = $true
        testerWriteTokenHashConfigured = $true
        maxSendUnits = "10"
        walletCreateSchema = $walletA.schema
        testerFaucetSchema = $faucetResponses[0].schema
        walletSendSchema = $send.schema
        accountCount = 2
        transferAccepted = $send.accepted
        transferStatus = $send.status
        transferId = $send.transferId
        capRejected = $true
        capRejectStatusCode = $overCap.statusCode
        capRejectSchema = $overCapBody.schema
        routes = @(
            "/tester/status",
            "/tester/wallets/create",
            "/tester/faucet",
            "/tester/wallets/send",
            "/rpc balance_get"
        )
        balancesAfter = [ordered]@{
            sender = "9"
            recipient = "11"
        }
        noLiveBroadcast = $true
        envValuesPrinted = $false
        noSecrets = $true
    }
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
        $serverProcess.WaitForExit(5000) | Out-Null
    }
    foreach ($name in $envNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnv[$name], "Process")
        if ($null -eq $originalEnv[$name]) {
            Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path "Env:\$name" -Value $originalEnv[$name]
        }
    }
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "public tester gateway E2E report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain public tester gateway E2E status: $($report.status)"
Write-Host "Report: $reportFullPath"
exit 0
