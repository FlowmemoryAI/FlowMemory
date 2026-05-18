param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json",
    [int] $MaxBlockAgeSeconds = 300,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)

$requiredEnv = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
)

$problems = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList
$endpointChecks = New-Object System.Collections.ArrayList
$responses = New-Object System.Collections.ArrayList

foreach ($name in $requiredEnv) {
    if ([string]::IsNullOrWhiteSpace((Get-FlowChainEnvValue -Name $name))) {
        [void] $missingEnv.Add($name)
        Add-FlowChainReadinessProblem -Problems $problems -Name $name -Reason "missing required public RPC env value"
    }
}

$publicUrl = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_PUBLIC_URL"
$allowedOriginsRaw = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS"
$rateLimitRaw = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE"
$tlsTerminatedRaw = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_TLS_TERMINATED"
$backupPathRaw = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH"

$publicUri = $null
$publicMode = $false
$explicitLocal = $false
if (-not [string]::IsNullOrWhiteSpace($publicUrl)) {
    if (-not [System.Uri]::TryCreate($publicUrl, [System.UriKind]::Absolute, [ref] $publicUri) -or ($publicUri.Scheme -notin @("http", "https"))) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "must be an absolute HTTP(S) URL" -Kind "failed"
    }
    else {
        $explicitLocal = Test-FlowChainLocalUri -Uri $publicUri
        $publicMode = -not $explicitLocal
        if ($publicMode -and $publicUri.Scheme -ne "https") {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "public RPC URL must use HTTPS" -Kind "failed"
        }
        if ($explicitLocal) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "explicit local URL can be checked but does not prove public RPC readiness"
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($tlsTerminatedRaw) -and $tlsTerminatedRaw.ToLowerInvariant() -ne "true") {
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_TLS_TERMINATED" -Reason "must equal true after owner TLS termination is configured" -Kind "failed"
}

$allowedOrigins = @()
if (-not [string]::IsNullOrWhiteSpace($allowedOriginsRaw)) {
    $allowedOrigins = @($allowedOriginsRaw.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
    if ($allowedOrigins.Count -eq 0) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "must contain at least one origin" -Kind "failed"
    }
    if ($publicMode -and @($allowedOrigins | Where-Object { $_ -in @("*", "null", "all", "ALL") }).Count -gt 0) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "broad wildcard origins are not allowed for public mode" -Kind "failed"
    }
}

$rateLimit = $null
if (-not [string]::IsNullOrWhiteSpace($rateLimitRaw)) {
    if ($rateLimitRaw -notmatch '^[1-9][0-9]*$') {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE" -Reason "must be a positive integer" -Kind "failed"
    }
    else {
        $rateLimit = [int64]$rateLimitRaw
    }
}

$backupCheck = [ordered]@{
    configured = -not [string]::IsNullOrWhiteSpace($backupPathRaw)
    exists = $false
    writable = $false
}
if (-not [string]::IsNullOrWhiteSpace($backupPathRaw)) {
    try {
        $backupFullPath = [System.IO.Path]::GetFullPath($backupPathRaw)
        if (-not (Test-Path -LiteralPath $backupFullPath)) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup path does not exist" -Kind "failed" -Category "artifact"
        }
        else {
            $backupItem = Get-Item -LiteralPath $backupFullPath
            if (-not $backupItem.PSIsContainer) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup path must be a directory" -Kind "failed" -Category "artifact"
            }
            else {
                $backupCheck.exists = $true
                $probePath = Join-Path $backupFullPath ".flowchain-rpc-backup-write-check-$PID.tmp"
                "flowchain-backup-write-check" | Set-Content -LiteralPath $probePath -Encoding UTF8
                $readBack = Get-Content -Raw -LiteralPath $probePath
                Remove-Item -LiteralPath $probePath -Force
                $backupCheck.writable = ($readBack -like "flowchain-backup-write-check*")
                if (-not $backupCheck.writable) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup path is not writable/readable" -Kind "failed" -Category "artifact"
                }
            }
        }
    }
    catch {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup path could not be verified" -Kind "failed" -Category "artifact"
    }
}

$stateFacts = Get-FlowChainStateFacts -StatePath $stateFullPath
if (-not $stateFacts.readable) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/state.json" -Reason "local node state file is missing or unreadable" -Category "artifact"
}

$endpointResults = [ordered]@{}
if ($null -ne $publicUri) {
    foreach ($endpoint in @("/health", "/rpc/discover", "/rpc/readiness", "/chain/status", "/wallets/operator", "/bridge/live-readiness")) {
        try {
            $response = Invoke-FlowChainJsonGet -PublicUrl $publicUrl -EndpointPath $endpoint
            [void] $responses.Add($response)
            $endpointResults[$endpoint] = [ordered]@{ status = "passed" }
            [void] $endpointChecks.Add([ordered]@{ endpoint = $endpoint; status = "passed" })
        }
        catch {
            $endpointResults[$endpoint] = [ordered]@{ status = "failed"; reason = "request failed" }
            [void] $endpointChecks.Add([ordered]@{ endpoint = $endpoint; status = "failed" })
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "could not read $endpoint from configured RPC endpoint" -Kind "failed" -Category "endpoint"
        }
    }

    foreach ($rpcCall in @(
            @{ method = "chain_status"; params = $null },
            @{ method = "node_status"; params = $null },
            @{ method = "mempool_list"; params = @{ limit = 1 } },
            @{ method = "peer_list"; params = @{ limit = 10 } }
        )) {
        try {
            $rpcResponse = Invoke-FlowChainJsonRpc -PublicUrl $publicUrl -Method $rpcCall.method -Params $rpcCall.params
            [void] $responses.Add($rpcResponse)
            [void] $endpointChecks.Add([ordered]@{ endpoint = "/rpc:$($rpcCall.method)"; status = "passed" })
        }
        catch {
            [void] $endpointChecks.Add([ordered]@{ endpoint = "/rpc:$($rpcCall.method)"; status = "failed" })
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "JSON-RPC method $($rpcCall.method) failed at configured endpoint" -Kind "failed" -Category "endpoint"
        }
    }
}

$health = if ($endpointResults.Contains("/health") -and $endpointResults["/health"].status -eq "passed") { $responses[0] } else { $null }
$discover = $null
$readiness = $null
$chainStatus = $null
try {
    if ($endpointResults.Contains("/rpc/discover") -and $endpointResults["/rpc/discover"].status -eq "passed") {
        $discover = Invoke-FlowChainJsonGet -PublicUrl $publicUrl -EndpointPath "/rpc/discover"
        [void] $responses.Add($discover)
    }
    if ($endpointResults.Contains("/rpc/readiness") -and $endpointResults["/rpc/readiness"].status -eq "passed") {
        $readiness = Invoke-FlowChainJsonGet -PublicUrl $publicUrl -EndpointPath "/rpc/readiness"
        [void] $responses.Add($readiness)
    }
    if ($endpointResults.Contains("/chain/status") -and $endpointResults["/chain/status"].status -eq "passed") {
        $chainStatus = Invoke-FlowChainJsonGet -PublicUrl $publicUrl -EndpointPath "/chain/status"
        [void] $responses.Add($chainStatus)
    }
}
catch {
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "configured endpoint response could not be re-read for comparison" -Kind "failed" -Category "endpoint"
}

$chainChecks = [ordered]@{
    chainIdMatches = $null
    latestHeightMatches = $null
    latestHashMatches = $null
    latestRootMatches = $null
    finalizedHeightMatches = $null
    blockAgeWithinLimit = $null
}

if ($null -ne $discover -and $stateFacts.readable) {
    $endpointChainId = Get-FlowChainJsonString -Object $discover -Names @("chainId")
    $chainChecks.chainIdMatches = ($endpointChainId -eq $stateFacts.chainId)
    if ($chainChecks.chainIdMatches -ne $true) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint chain id does not match local node state" -Kind "failed" -Category "endpoint"
    }
}

if ($null -ne $chainStatus -and $stateFacts.readable) {
    $endpointHeight = Get-FlowChainJsonString -Object $chainStatus -Names @("blockHeight", "currentBlock")
    $endpointHash = Get-FlowChainJsonString -Object $chainStatus -Names @("currentBlockHash", "latestBlockHash")
    $endpointRoot = Get-FlowChainJsonString -Object $chainStatus -Names @("latestStateRoot", "stateRoot")
    $endpointFinalized = Get-FlowChainJsonString -Object $chainStatus -Names @("finalizedBlock", "finalizedHeight")

    $chainChecks.latestHeightMatches = ($endpointHeight -eq $stateFacts.latestHeight)
    $chainChecks.latestHashMatches = ($endpointHash -eq $stateFacts.latestHash)
    $chainChecks.latestRootMatches = ($endpointRoot -eq $stateFacts.latestRoot)
    $chainChecks.finalizedHeightMatches = ($endpointFinalized -eq $stateFacts.finalizedHeight)

    if ($chainChecks.latestHeightMatches -ne $true) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint latest block height does not match local node state" -Kind "failed" -Category "endpoint"
    }
    if ($chainChecks.latestHashMatches -ne $true) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint latest block hash does not match local node state" -Kind "failed" -Category "endpoint"
    }
    if ($chainChecks.latestRootMatches -ne $true) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint latest state root does not match local node state" -Kind "failed" -Category "endpoint"
    }
    if ($chainChecks.finalizedHeightMatches -ne $true) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint finalized height does not match local node state" -Kind "failed" -Category "endpoint"
    }
}

if ($null -ne $stateFacts.latestBlockAgeSeconds) {
    $chainChecks.blockAgeWithinLimit = ([int64]$stateFacts.latestBlockAgeSeconds -le $MaxBlockAgeSeconds)
    if ($chainChecks.blockAgeWithinLimit -ne $true) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/state.json" -Reason "latest block age exceeds live RPC freshness limit" -Kind "failed" -Category "artifact"
    }
}
elseif ($stateFacts.readable) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/state.json" -Reason "latest block timestamp is missing; block production age cannot be verified" -Category "artifact"
}

if ($null -ne $readiness) {
    $readinessStatus = Get-FlowChainJsonString -Object $readiness -Names @("status")
    if ($readinessStatus -ne "READY_FOR_CONFIGURED_OWNER_RPC_DEPLOYMENT") {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint /rpc/readiness is not ready" -Category "endpoint"
    }
}

$hygiene = Test-FlowChainResponseHygiene -Responses @($responses) -EnvNames $requiredEnv
if (-not $hygiene.passed) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint responses included raw env values or secret-shaped material" -Kind "failed" -Category "endpoint"
}

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }
$publicRpcReady = ($status -eq "passed" -and $publicMode)

$report = [ordered]@{
    schema = "flowchain.public_rpc_readiness_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    publicRpcReady = $publicRpcReady
    publicMode = $publicMode
    explicitLocalEndpoint = $explicitLocal
    requiredEnvNames = $requiredEnv
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    endpointValuePrinted = $false
    envValuesPrinted = $false
    checks = [ordered]@{
        urlConfigured = -not [string]::IsNullOrWhiteSpace($publicUrl)
        httpsRequiredForPublicMode = $true
        tlsTerminatedAcknowledged = ($tlsTerminatedRaw -eq "true")
        allowedOriginsConfigured = $allowedOrigins.Count -gt 0
        allowedOriginsWildcardRejected = $publicMode
        numericRateLimit = $null -ne $rateLimit
        backupPathConfigured = $backupCheck.configured
        backupPathExists = $backupCheck.exists
        backupPathWritable = $backupCheck.writable
        stateFileReadable = $stateFacts.readable
        responseHygienePassed = $hygiene.passed
    }
    endpointChecks = @($endpointChecks)
    chainChecks = $chainChecks
    localState = [ordered]@{
        statePath = $StatePath
        chainId = $stateFacts.chainId
        latestHeight = $stateFacts.latestHeight
        latestHash = $stateFacts.latestHash
        latestRoot = $stateFacts.latestRoot
        latestBlockAgeSeconds = $stateFacts.latestBlockAgeSeconds
        stateFileLastWriteAgeSeconds = $stateFacts.stateFileLastWriteAgeSeconds
        finalizedHeight = $stateFacts.finalizedHeight
        finalizedHash = $stateFacts.finalizedHash
        mempoolDepth = $stateFacts.mempoolDepth
        peerCount = $stateFacts.peerCount
    }
    maxBlockAgeSeconds = $MaxBlockAgeSeconds
    responseHygiene = $hygiene
    problems = @($problems)
    noSecrets = $hygiene.passed
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

Write-Host "FlowChain public RPC readiness status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "Public RPC readiness $status. See report for env and artifact names."
}
