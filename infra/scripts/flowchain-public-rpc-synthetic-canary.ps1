param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_SYNTHETIC_CANARY.md",
    [int] $TimeoutSec = 10,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$requiredEnv = @("FLOWCHAIN_RPC_PUBLIC_URL")
$plannedReadPaths = @("/health", "/rpc/discover", "/rpc/readiness", "/chain/status")
$plannedReadMethods = @("chain_status", "node_status", "block_list", "mempool_list")
$readMethodParams = @{
    chain_status = $null
    node_status = $null
    block_list = @{ limit = 2 }
    mempool_list = @{ limit = 2 }
}
$writeMethodDenylist = @(
    "transaction_submit",
    "wallet_send",
    "wallet_create",
    "tester_wallet_send",
    "faucet_request",
    "bridge_credit_apply"
)

function Add-CanaryProblem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Problems,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Reason,
        [ValidateSet("blocked", "failed")]
        [string] $Kind = "blocked",
        [ValidateSet("env", "endpoint", "policy")]
        [string] $Category = "env"
    )

    [void] $Problems.Add([ordered]@{
        name = $Name
        category = $Category
        kind = $Kind
        reason = $Reason
    })
}

function Add-CanaryProbe {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Probes,
        [Parameter(Mandatory = $true)][string] $Kind,
        [Parameter(Mandatory = $true)][string] $Target,
        [Parameter(Mandatory = $true)][string] $Status,
        [string] $Schema = "",
        [string] $Reason = ""
    )

    [void] $Probes.Add([ordered]@{
        kind = $Kind
        target = $Target
        status = $Status
        schema = $Schema
        reason = $Reason
    })
}

function Get-CanaryProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Get-CanaryResponseSchema {
    param([AllowNull()][object] $Response)

    $result = Get-CanaryProp -Object $Response -Name "result"
    $schema = Get-FlowChainJsonString -Object $Response -Names @("schema")
    if ([string]::IsNullOrWhiteSpace($schema)) {
        $schema = Get-FlowChainJsonString -Object $result -Names @("schema")
    }
    if ([string]::IsNullOrWhiteSpace($schema)) {
        return ""
    }
    return $schema
}

$problems = New-Object System.Collections.ArrayList
$probes = New-Object System.Collections.ArrayList
$responses = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList

foreach ($name in $requiredEnv) {
    if ([string]::IsNullOrWhiteSpace((Get-FlowChainEnvValue -Name $name))) {
        [void] $missingEnv.Add($name)
        Add-CanaryProblem -Problems $problems -Name $name -Reason "missing required public endpoint value"
    }
}

$publicEndpoint = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_PUBLIC_URL"
$publicUri = $null
$endpointConfigured = -not [string]::IsNullOrWhiteSpace($publicEndpoint)
$endpointAbsoluteHttp = $false
$publicMode = $false
$explicitLocalEndpoint = $false
$networkProbeAllowed = $false

if ($endpointConfigured) {
    if (-not [System.Uri]::TryCreate($publicEndpoint, [System.UriKind]::Absolute, [ref] $publicUri) -or ($publicUri.Scheme -notin @("http", "https"))) {
        Add-CanaryProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "must be an absolute HTTP(S) endpoint" -Kind "failed"
    }
    else {
        $endpointAbsoluteHttp = $true
        $explicitLocalEndpoint = Test-FlowChainLocalUri -Uri $publicUri
        $publicMode = -not $explicitLocalEndpoint
        if ($explicitLocalEndpoint) {
            Add-CanaryProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "local endpoint can be useful during development but does not prove public RPC canary readiness" -Category "endpoint"
        }
        elseif ($publicUri.Scheme -ne "https") {
            Add-CanaryProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "public synthetic canary requires HTTPS" -Kind "failed" -Category "endpoint"
        }
        else {
            $networkProbeAllowed = $true
        }
    }
}

$plannedWriteMethods = @($plannedReadMethods | Where-Object { $_ -in $writeMethodDenylist })
if ($plannedWriteMethods.Count -gt 0) {
    Add-CanaryProblem -Problems $problems -Name "read-method-allowlist" -Reason "planned method list includes a write-shaped RPC method" -Kind "failed" -Category "policy"
    $networkProbeAllowed = $false
}

if ($networkProbeAllowed) {
    foreach ($path in $plannedReadPaths) {
        try {
            $response = Invoke-FlowChainJsonGet -PublicUrl $publicEndpoint -EndpointPath $path -TimeoutSec $TimeoutSec
            [void] $responses.Add($response)
            Add-CanaryProbe -Probes $probes -Kind "http-get" -Target $path -Status "passed" -Schema (Get-CanaryResponseSchema -Response $response)
        }
        catch {
            Add-CanaryProbe -Probes $probes -Kind "http-get" -Target $path -Status "failed" -Reason "request failed"
            Add-CanaryProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "could not read $path from configured public endpoint" -Kind "failed" -Category "endpoint"
        }
    }

    foreach ($method in $plannedReadMethods) {
        if ($method -in $writeMethodDenylist) {
            Add-CanaryProbe -Probes $probes -Kind "json-rpc" -Target $method -Status "skipped" -Reason "write method denied"
            Add-CanaryProblem -Problems $problems -Name "read-method-allowlist" -Reason "blocked write-shaped method $method before invocation" -Kind "failed" -Category "policy"
            continue
        }

        try {
            $response = Invoke-FlowChainJsonRpc -PublicUrl $publicEndpoint -Method $method -Params $readMethodParams[$method] -TimeoutSec $TimeoutSec
            [void] $responses.Add($response)
            Add-CanaryProbe -Probes $probes -Kind "json-rpc" -Target $method -Status "passed" -Schema (Get-CanaryResponseSchema -Response $response)
        }
        catch {
            Add-CanaryProbe -Probes $probes -Kind "json-rpc" -Target $method -Status "failed" -Reason "request failed"
            Add-CanaryProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "read-only JSON-RPC method $method failed at configured public endpoint" -Kind "failed" -Category "endpoint"
        }
    }
}

$hygiene = if ($responses.Count -gt 0) {
    Test-FlowChainResponseHygiene -Responses @($responses) -EnvNames $requiredEnv
}
else {
    [ordered]@{
        passed = $true
        findings = @()
    }
}
if (-not $hygiene.passed) {
    Add-CanaryProblem -Problems $problems -Name "FLOWCHAIN_RPC_PUBLIC_URL" -Reason "synthetic canary response included raw env values or secret-shaped material" -Kind "failed" -Category "endpoint"
}

$failedProblems = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failedProblems.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }
$failedProbes = @($probes | Where-Object { $_.status -eq "failed" })
$passedProbes = @($probes | Where-Object { $_.status -eq "passed" })
$blockedOnlyOnKnownExternalOwnerInputs = $status -eq "blocked" -and $failedProblems.Count -eq 0 -and @($problems | Where-Object { $_.name -notin $requiredEnv }).Count -eq 0
$syntheticCanaryReady = $status -eq "passed" -and $publicMode -and $passedProbes.Count -eq ($plannedReadPaths.Count + $plannedReadMethods.Count)

$packageScripts = @(Get-FlowChainPackageScripts -RepoRoot $repoRoot)
$checks = [ordered]@{
    packageScriptPresent = $packageScripts -contains "flowchain:public-rpc:synthetic-canary"
    endpointConfigured = $endpointConfigured
    endpointAbsoluteHttp = $endpointAbsoluteHttp
    endpointValuePrintedFalse = $true
    publicModeNonLocal = $publicMode
    httpsRequiredForPublicMode = (-not $publicMode) -or ($null -ne $publicUri -and $publicUri.Scheme -eq "https")
    noNetworkUntilEndpointConfigured = $endpointConfigured -or $probes.Count -eq 0
    networkProbeSkippedWhileOwnerBlocked = if ($endpointConfigured) { $explicitLocalEndpoint -or $networkProbeAllowed -or $failedProblems.Count -gt 0 } else { $probes.Count -eq 0 }
    safeReadMethodAllowlistEnforced = $plannedWriteMethods.Count -eq 0
    noWriteMethodsPlanned = $plannedWriteMethods.Count -eq 0
    noWriteMethodsInvoked = @($probes | Where-Object { $_.target -in $writeMethodDenylist }).Count -eq 0
    plannedReadPathsCovered = $plannedReadPaths.Count -eq 4
    plannedReadMethodsCovered = $plannedReadMethods.Count -eq 4
    allProbesPassedWhenNetworkAllowed = (-not $networkProbeAllowed) -or ($failedProbes.Count -eq 0 -and $passedProbes.Count -eq ($plannedReadPaths.Count + $plannedReadMethods.Count))
    responseHygienePassed = $hygiene.passed
    broadcastsFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $hygiene.passed
    secretMarkerFindingsEmpty = @((Get-CanaryProp -Object $hygiene -Name "findings" -Default @())).Count -eq 0
}

$report = [ordered]@{
    schema = "flowchain.public_rpc_synthetic_canary_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    syntheticCanaryReady = $syntheticCanaryReady
    blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownExternalOwnerInputs
    requiredEnvNames = $requiredEnv
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    endpointConfigured = $endpointConfigured
    endpointHostRedacted = if ($endpointConfigured -and $endpointAbsoluteHttp) { "<configured-public-endpoint>" } else { "" }
    endpointValuePrinted = $false
    publicMode = $publicMode
    explicitLocalEndpoint = $explicitLocalEndpoint
    networkProbeAllowed = $networkProbeAllowed
    plannedReadPaths = $plannedReadPaths
    plannedReadMethods = $plannedReadMethods
    deniedWriteMethods = $writeMethodDenylist
    probes = @($probes)
    probeCount = $probes.Count
    passedProbeCount = $passedProbes.Count
    failedProbeCount = $failedProbes.Count
    responseHygiene = $hygiene
    checks = $checks
    problems = @($problems)
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $hygiene.passed
    secretMarkerFindings = @((Get-CanaryProp -Object $hygiene -Name "findings" -Default @()))
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC synthetic canary report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = @(
    "# FlowChain Public RPC Synthetic Canary",
    "",
    "Generated: $($report.generatedAt)",
    "Status: $status",
    "",
    "This canary runs only read-only public endpoint probes. It does not create wallets, request faucet funds, submit transactions, or broadcast bridge operations.",
    "",
    "## Public Launch Boundary",
    "",
    "- Required owner input names: ``$($requiredEnv -join ', ')``",
    "- Missing owner input names: ``$((@($missingEnv | Select-Object -Unique)) -join ', ')``",
    "- Endpoint value printed: ``false``",
    "- Network probes run: ``$networkProbeAllowed``",
    "",
    "## Probe Plan",
    "",
    "- HTTP GET paths: ``$($plannedReadPaths -join ', ')``",
    "- JSON-RPC methods: ``$($plannedReadMethods -join ', ')``",
    "- Denied write methods: ``$($writeMethodDenylist -join ', ')``",
    "",
    "## Artifacts",
    "",
    "- Report: docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
)
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC synthetic canary markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public RPC synthetic canary status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain public RPC synthetic canary $status. See report for env and endpoint status names."
}
