param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json",
    [int] $MaxBlockAgeSeconds = 300,
    [int] $RateLimitProbeMaxRequests = 300,
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
$corsCheck = [ordered]@{
    performed = $false
    allowOriginHeaderPresent = $false
    configuredOriginAccepted = $false
    disallowedOriginProbePerformed = $false
    disallowedOriginRejected = $false
    wildcardRejectedForPublicMode = $true
    headerValuePrinted = $false
}
$rateLimitCheck = [ordered]@{
    configured = $false
    probePerformed = $false
    probeRequestLimit = $RateLimitProbeMaxRequests
    configuredLimit = $null
    requestCount = 0
    rejectionObserved = $false
    retryAfterHeaderPresent = $false
    skippedBecauseAboveProbeLimit = $false
}
$deploymentChecks = [ordered]@{
    readinessEndpointPresent = $false
    readinessStatusReady = $null
    readinessPublicRpcReady = $null
    readinessProductionReady = $null
    readinessLocalOnlyFalse = $null
    readinessDeploymentModePublicEdge = $null
    discoverEndpointPresent = $false
    discoverPublicRpcReadyMatchesReadiness = $null
    discoverProductionReadyMatchesReadiness = $null
    discoverLocalOnlyMatchesReadiness = $null
    discoverDeploymentModeMatchesReadiness = $null
    publicReadyMethodCountNonzeroWhenReady = $null
}

function Get-FlowChainJsonPropertyValue {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $null
}

function New-FlowChainSkippedStateFacts {
    param([Parameter(Mandatory = $true)][string] $Reason)

    return [ordered]@{
        readable = $null
        skipped = $true
        skipReason = $Reason
        statePathConfigured = $true
        chainId = $null
        latestHeight = $null
        latestHash = $null
        latestRoot = $null
        latestBlockAgeSeconds = $null
        stateFileLastWriteAgeSeconds = $null
        finalizedHeight = $null
        finalizedHash = $null
        mempoolDepth = $null
        peerCount = $null
    }
}

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
        $rateLimitCheck.configured = $true
        $rateLimitCheck.configuredLimit = $rateLimit
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

$stateFactsShouldLoad = $null -ne $publicUri
$stateFacts = if ($stateFactsShouldLoad) {
    Get-FlowChainStateFacts -StatePath $stateFullPath
}
else {
    New-FlowChainSkippedStateFacts -Reason "Public RPC URL is not configured or valid, so endpoint-to-state comparison is not actionable."
}
if ($stateFactsShouldLoad -and -not $stateFacts.readable) {
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

if ($null -ne $publicUri -and $allowedOrigins.Count -gt 0) {
    try {
        $corsProbeUrl = Join-FlowChainEndpointUri -PublicUrl $publicUrl -EndpointPath "/health"
        $corsProbe = Invoke-WebRequest -Uri $corsProbeUrl -Method Get -Headers @{ Origin = $allowedOrigins[0] } -TimeoutSec 10 -UseBasicParsing
        $corsHeader = "$($corsProbe.Headers["Access-Control-Allow-Origin"])"
        $corsCheck.performed = $true
        $corsCheck.allowOriginHeaderPresent = -not [string]::IsNullOrWhiteSpace($corsHeader)
        $corsCheck.configuredOriginAccepted = ($corsHeader -eq $allowedOrigins[0])
        $corsCheck.wildcardRejectedForPublicMode = -not ($publicMode -and $corsHeader -eq "*")
        if (-not $corsCheck.allowOriginHeaderPresent) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "configured endpoint did not return an Access-Control-Allow-Origin header" -Kind "failed" -Category "endpoint"
        }
        if ($publicMode -and $corsHeader -eq "*") {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "configured public endpoint returned wildcard CORS" -Kind "failed" -Category "endpoint"
        }
        if ($publicMode -and $corsHeader -ne $allowedOrigins[0]) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "configured public endpoint did not return the requested allowed origin" -Kind "failed" -Category "endpoint"
        }

        $blockedOrigin = "https://flowchain-disallowed-origin.invalid"
        if ($allowedOrigins -contains $blockedOrigin) {
            $blockedOrigin = "https://flowchain-not-allowed.invalid"
        }
        $corsCheck.disallowedOriginProbePerformed = $true
        try {
            $blockedProbe = Invoke-WebRequest -Uri $corsProbeUrl -Method Get -Headers @{ Origin = $blockedOrigin } -TimeoutSec 10 -UseBasicParsing
            $blockedHeader = "$($blockedProbe.Headers["Access-Control-Allow-Origin"])"
            $corsCheck.disallowedOriginRejected = $false
            if ($publicMode) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "configured public endpoint accepted a disallowed browser origin" -Kind "failed" -Category "endpoint"
            }
        }
        catch {
            $statusCode = $null
            if ($null -ne $_.Exception.Response) {
                try {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                catch {
                    $statusCode = $null
                }
            }
            if ($statusCode -eq 403) {
                $corsCheck.disallowedOriginRejected = $true
            }
            elseif ($publicMode) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "configured endpoint disallowed-origin probe failed without a 403 rejection" -Kind "failed" -Category "endpoint"
            }
        }
        if ($publicMode -and $corsCheck.disallowedOriginRejected -ne $true) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "configured public endpoint did not reject a disallowed browser origin" -Kind "failed" -Category "endpoint"
        }
    }
    catch {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS" -Reason "configured endpoint CORS probe failed" -Kind "failed" -Category "endpoint"
    }
}

if ($null -ne $publicUri -and $null -ne $rateLimit) {
    if ($rateLimit -gt $RateLimitProbeMaxRequests) {
        $rateLimitCheck.skippedBecauseAboveProbeLimit = $true
        if ($publicMode) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE" -Reason "configured public rate limit is above the bounded readiness probe limit" -Kind "failed" -Category "endpoint"
        }
    }
    else {
        $rateLimitCheck.probePerformed = $true
        $rateProbeUrl = Join-FlowChainEndpointUri -PublicUrl $publicUrl -EndpointPath "/health"
        $rateProbeClient = "198.51.100.$([Math]::Max(1, ($PID % 250)))"
        $rateProbeHeaders = @{
            "X-Forwarded-For" = $rateProbeClient
        }
        if ($allowedOrigins.Count -gt 0) {
            $rateProbeHeaders["Origin"] = $allowedOrigins[0]
        }
        for ($requestNumber = 1; $requestNumber -le ($rateLimit + 1); $requestNumber++) {
            $rateLimitCheck.requestCount = $requestNumber
            try {
                $rateProbe = Invoke-WebRequest -Uri $rateProbeUrl -Method Get -Headers $rateProbeHeaders -TimeoutSec 10 -UseBasicParsing
                if ([int]$rateProbe.StatusCode -eq 429) {
                    $rateLimitCheck.rejectionObserved = $true
                    $rateLimitCheck.retryAfterHeaderPresent = -not [string]::IsNullOrWhiteSpace("$($rateProbe.Headers["Retry-After"])")
                    break
                }
            }
            catch {
                $statusCode = $null
                $retryAfter = ""
                if ($null -ne $_.Exception.Response) {
                    try {
                        $statusCode = [int]$_.Exception.Response.StatusCode
                        $retryAfter = "$($_.Exception.Response.Headers["Retry-After"])"
                    }
                    catch {
                        $statusCode = $null
                    }
                }
                if ($statusCode -eq 429) {
                    $rateLimitCheck.rejectionObserved = $true
                    $rateLimitCheck.retryAfterHeaderPresent = -not [string]::IsNullOrWhiteSpace($retryAfter)
                    break
                }
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE" -Reason "configured endpoint rate-limit probe failed before observing 429" -Kind "failed" -Category "endpoint"
                break
            }
        }
        if (-not $rateLimitCheck.rejectionObserved) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE" -Reason "configured endpoint did not enforce rate limiting during bounded probe" -Kind "failed" -Category "endpoint"
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
    $stateFactsAfterEndpoint = Get-FlowChainStateFacts -StatePath $stateFullPath
    $endpointBlockFacts = Get-FlowChainBlockFacts -StatePath $stateFullPath -BlockNumber $endpointHeight

    $chainChecks.latestHeightMatches = (
        $endpointHeight -eq $stateFacts.latestHeight -or
        $endpointHeight -eq $stateFactsAfterEndpoint.latestHeight -or
        $endpointBlockFacts.found
    )
    $chainChecks.latestHashMatches = (
        $endpointHash -eq $stateFacts.latestHash -or
        $endpointHash -eq $stateFactsAfterEndpoint.latestHash -or
        ($endpointBlockFacts.found -and $endpointHash -eq $endpointBlockFacts.blockHash)
    )
    $chainChecks.latestRootMatches = (
        $endpointRoot -eq $stateFacts.latestRoot -or
        $endpointRoot -eq $stateFactsAfterEndpoint.latestRoot -or
        ($endpointBlockFacts.found -and $endpointRoot -eq $endpointBlockFacts.stateRoot)
    )
    $chainChecks.finalizedHeightMatches = (
        $endpointFinalized -eq $stateFacts.finalizedHeight -or
        $endpointFinalized -eq $stateFactsAfterEndpoint.finalizedHeight -or
        ($endpointBlockFacts.found -and $endpointFinalized -eq $endpointHeight)
    )

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
    $deploymentChecks.readinessEndpointPresent = $true
    $readinessStatus = Get-FlowChainJsonString -Object $readiness -Names @("status")
    $readinessPublicRpcReady = Get-FlowChainJsonPropertyValue -Object $readiness -Name "publicRpcReady"
    $readinessProductionReady = Get-FlowChainJsonPropertyValue -Object $readiness -Name "productionReady"
    $readinessLocalOnly = Get-FlowChainJsonPropertyValue -Object $readiness -Name "localOnly"
    $readinessDeploymentMode = Get-FlowChainJsonString -Object $readiness -Names @("deploymentMode")
    $readinessPublicReadyMethodCount = Get-FlowChainJsonPropertyValue -Object $readiness -Name "publicReadyMethodCount"

    $deploymentChecks.readinessStatusReady = $readinessStatus -eq "READY_FOR_CONFIGURED_OWNER_RPC_DEPLOYMENT"
    $deploymentChecks.readinessPublicRpcReady = $readinessPublicRpcReady -eq $true
    $deploymentChecks.readinessProductionReady = $readinessProductionReady -eq $true
    $deploymentChecks.readinessLocalOnlyFalse = $readinessLocalOnly -eq $false
    $deploymentChecks.readinessDeploymentModePublicEdge = $readinessDeploymentMode -eq "public-owner-edge"
    $deploymentChecks.publicReadyMethodCountNonzeroWhenReady = if ($readinessStatus -eq "READY_FOR_CONFIGURED_OWNER_RPC_DEPLOYMENT") { [int64]$readinessPublicReadyMethodCount -gt 0 } else { $null }

    if ($readinessStatus -ne "READY_FOR_CONFIGURED_OWNER_RPC_DEPLOYMENT") {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint /rpc/readiness is not ready" -Category "endpoint"
    }
    elseif (
        $deploymentChecks.readinessPublicRpcReady -ne $true -or
        $deploymentChecks.readinessProductionReady -ne $true -or
        $deploymentChecks.readinessLocalOnlyFalse -ne $true -or
        $deploymentChecks.readinessDeploymentModePublicEdge -ne $true -or
        $deploymentChecks.publicReadyMethodCountNonzeroWhenReady -ne $true
    ) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint /rpc/readiness reports ready status with contradictory public deployment flags" -Kind "failed" -Category "endpoint"
    }
}

if ($null -ne $discover) {
    $deploymentChecks.discoverEndpointPresent = $true
    if ($null -ne $readiness) {
        $discoverPublicRpcReady = Get-FlowChainJsonPropertyValue -Object $discover -Name "publicRpcReady"
        $discoverProductionReady = Get-FlowChainJsonPropertyValue -Object $discover -Name "productionReady"
        $discoverLocalOnly = Get-FlowChainJsonPropertyValue -Object $discover -Name "localOnly"
        $discoverDeploymentMode = Get-FlowChainJsonString -Object $discover -Names @("deploymentMode")
        $readinessPublicRpcReady = Get-FlowChainJsonPropertyValue -Object $readiness -Name "publicRpcReady"
        $readinessProductionReady = Get-FlowChainJsonPropertyValue -Object $readiness -Name "productionReady"
        $readinessLocalOnly = Get-FlowChainJsonPropertyValue -Object $readiness -Name "localOnly"
        $readinessDeploymentMode = Get-FlowChainJsonString -Object $readiness -Names @("deploymentMode")

        $deploymentChecks.discoverPublicRpcReadyMatchesReadiness = $discoverPublicRpcReady -eq $readinessPublicRpcReady
        $deploymentChecks.discoverProductionReadyMatchesReadiness = $discoverProductionReady -eq $readinessProductionReady
        $deploymentChecks.discoverLocalOnlyMatchesReadiness = $discoverLocalOnly -eq $readinessLocalOnly
        $deploymentChecks.discoverDeploymentModeMatchesReadiness = $discoverDeploymentMode -eq $readinessDeploymentMode
        if (
            $deploymentChecks.discoverPublicRpcReadyMatchesReadiness -ne $true -or
            $deploymentChecks.discoverProductionReadyMatchesReadiness -ne $true -or
            $deploymentChecks.discoverLocalOnlyMatchesReadiness -ne $true -or
            $deploymentChecks.discoverDeploymentModeMatchesReadiness -ne $true
        ) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "endpoint /rpc/discover deployment flags do not match /rpc/readiness" -Kind "failed" -Category "endpoint"
        }
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
        allowedOriginsWildcardRejected = ((-not $publicMode) -or @($allowedOrigins | Where-Object { $_ -in @("*", "null", "all", "ALL") }).Count -eq 0)
        numericRateLimit = $null -ne $rateLimit
        rateLimitProbePerformed = $rateLimitCheck.probePerformed
        rateLimitRejectionObserved = $rateLimitCheck.rejectionObserved
        rateLimitRetryAfterHeaderPresent = $rateLimitCheck.retryAfterHeaderPresent
        rateLimitProbeWithinMax = -not $rateLimitCheck.skippedBecauseAboveProbeLimit
        corsProbePerformed = $corsCheck.performed
        corsAllowOriginHeaderPresent = $corsCheck.allowOriginHeaderPresent
        corsConfiguredOriginAccepted = $corsCheck.configuredOriginAccepted
        corsDisallowedOriginProbePerformed = $corsCheck.disallowedOriginProbePerformed
        corsDisallowedOriginRejected = $corsCheck.disallowedOriginRejected
        corsWildcardRejectedForPublicMode = $corsCheck.wildcardRejectedForPublicMode
        backupPathConfigured = $backupCheck.configured
        backupPathExists = $backupCheck.exists
        backupPathWritable = $backupCheck.writable
        stateFactsLoaded = $stateFactsShouldLoad
        stateFactsSkippedUntilPublicUrlConfigured = -not $stateFactsShouldLoad
        stateFileReadable = $stateFacts.readable
        responseHygienePassed = $hygiene.passed
        readinessDeploymentFlagsConsistent = $deploymentChecks.readinessStatusReady -ne $true -or (
            $deploymentChecks.readinessPublicRpcReady -eq $true -and
            $deploymentChecks.readinessProductionReady -eq $true -and
            $deploymentChecks.readinessLocalOnlyFalse -eq $true -and
            $deploymentChecks.readinessDeploymentModePublicEdge -eq $true -and
            $deploymentChecks.publicReadyMethodCountNonzeroWhenReady -eq $true
        )
        discoveryMatchesReadinessDeployment = $deploymentChecks.discoverEndpointPresent -ne $true -or $deploymentChecks.readinessEndpointPresent -ne $true -or (
            $deploymentChecks.discoverPublicRpcReadyMatchesReadiness -eq $true -and
            $deploymentChecks.discoverProductionReadyMatchesReadiness -eq $true -and
            $deploymentChecks.discoverLocalOnlyMatchesReadiness -eq $true -and
            $deploymentChecks.discoverDeploymentModeMatchesReadiness -eq $true
        )
    }
    deploymentChecks = $deploymentChecks
    endpointChecks = @($endpointChecks)
    chainChecks = $chainChecks
    localState = [ordered]@{
        statePath = $StatePath
        skipped = (Get-FlowChainJsonPropertyValue -Object $stateFacts -Name "skipped")
        skipReason = (Get-FlowChainJsonPropertyValue -Object $stateFacts -Name "skipReason")
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
    cors = $corsCheck
    rateLimit = $rateLimitCheck
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
