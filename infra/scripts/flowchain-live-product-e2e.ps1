param(
    [string] $ReportDir = "devnet/local/live-product-e2e",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportDir)
$logsDir = Join-Path $reportFullDir "logs"
$reportPath = Join-Path $reportFullDir "flowchain-live-product-e2e-report.json"
$summaryPath = Join-Path $reportFullDir "flowchain-live-product-e2e-summary.md"

$reportFullDir = Reset-FlowChainDirectory -Path $reportFullDir
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$npmCacheDir = Join-Path $reportFullDir "npm-cache"
New-Item -ItemType Directory -Force -Path $npmCacheDir | Out-Null
$previousNpmCache = [Environment]::GetEnvironmentVariable("npm_config_cache", "Process")
$env:npm_config_cache = $npmCacheDir

$steps = New-Object System.Collections.ArrayList
$blockers = New-Object System.Collections.ArrayList
$commandsRun = New-Object System.Collections.ArrayList

function Get-SafeLiveProductStepName {
    param([string] $Name)
    return (($Name -replace '[^A-Za-z0-9_.-]', '-') -replace '-+', '-').Trim("-")
}

function Read-LiveProductJsonIfExists {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-LiveProductRootScripts {
    $packagePath = Join-Path $repoRoot "package.json"
    $packageJson = Get-Content -Raw -LiteralPath $packagePath | ConvertFrom-Json
    return @($packageJson.scripts.PSObject.Properties.Name)
}

function Add-LiveProductBlocker {
    param(
        [string] $Code,
        [string] $Owner,
        [string] $Reason,
        [string] $Command = "",
        [string] $ReportPath = "",
        [string[]] $EnvNames = @()
    )

    [void] $blockers.Add([ordered]@{
        code = $Code
        owner = $Owner
        reason = $Reason
        command = $Command
        reportPath = $ReportPath
        envNames = @($EnvNames)
    })
}

function Invoke-LiveProductStep {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Owner,

        [Parameter(Mandatory = $true)]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $ArgumentList = @(),

        [ValidateSet("local", "live", "release", "security")]
        [string] $Scope = "local",

        [switch] $AllowFailure,

        [string] $ExpectedReportPath = ""
    )

    $safe = Get-SafeLiveProductStepName -Name $Name
    $logPath = Join-Path $logsDir "$safe.log"
    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    [void] $commandsRun.Add($Command)

    Write-Host ""
    Write-Host "== $Name =="
    Write-Host $Command

    $previousErrorActionPreference = $ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        $output = (& $FilePath @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $script:ErrorActionPreference = $previousErrorActionPreference
    }

    $output | Set-Content -LiteralPath $logPath -Encoding utf8
    $endedAt = (Get-Date).ToUniversalTime().ToString("o")
    $status = if ($exitCode -eq 0) { "passed" } elseif ($AllowFailure) { "blocked" } else { "failed" }
    $reason = if ($exitCode -eq 0) { "" } else { (($output | Select-Object -Last 12) -join [Environment]::NewLine) }

    $step = [ordered]@{
        name = $Name
        owner = $Owner
        command = $Command
        status = $status
        exitCode = $exitCode
        scope = $Scope
        logPath = $logPath
        reportPath = $ExpectedReportPath
        startedAt = $startedAt
        endedAt = $endedAt
        reason = $reason
    }
    [void] $steps.Add($step)

    if ($status -eq "failed") {
        Add-LiveProductBlocker -Code "step-failed" -Owner $Owner -Reason $reason -Command $Command -ReportPath $ExpectedReportPath
    }
    elseif ($status -eq "blocked") {
        Add-LiveProductBlocker -Code "step-blocked" -Owner $Owner -Reason $reason -Command $Command -ReportPath $ExpectedReportPath
    }

    Write-Host "$($status.ToUpperInvariant()): $Name"
    return $step
}

function Add-MissingCommandStep {
    param(
        [string] $Name,
        [string] $Owner,
        [string] $Command,
        [string] $Reason
    )

    [void] $steps.Add([ordered]@{
        name = $Name
        owner = $Owner
        command = $Command
        status = "blocked"
        exitCode = 1
        scope = "release"
        logPath = ""
        reportPath = ""
        startedAt = (Get-Date).ToUniversalTime().ToString("o")
        endedAt = (Get-Date).ToUniversalTime().ToString("o")
        reason = $Reason
    })
    Add-LiveProductBlocker -Code "missing-command" -Owner $Owner -Reason $Reason -Command $Command
}

function Add-BlockedLiveProductStep {
    param(
        [string] $Name,
        [string] $Owner,
        [string] $Command,
        [string] $Reason,
        [string] $Scope = "live",
        [string] $ReportPath = "",
        [string[]] $EnvNames = @()
    )

    [void] $commandsRun.Add($Command)
    [void] $steps.Add([ordered]@{
        name = $Name
        owner = $Owner
        command = $Command
        status = "blocked"
        exitCode = 1
        scope = $Scope
        logPath = ""
        reportPath = $ReportPath
        startedAt = (Get-Date).ToUniversalTime().ToString("o")
        endedAt = (Get-Date).ToUniversalTime().ToString("o")
        reason = $Reason
    })
    Add-LiveProductBlocker -Code "step-blocked" -Owner $Owner -Reason $Reason -Command $Command -ReportPath $ReportPath -EnvNames $EnvNames
}

function Get-JsonPropertyValue {
    param(
        [AllowNull()][object] $Object,
        [string] $Name,
        [object] $Fallback = $null
    )
    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
        return $Fallback
    }
    return $Object.$Name
}

Write-Host "FlowChain live-product:e2e release gate starting."
Write-Host "Report directory: $reportFullDir"
Write-Host "Live env values are not printed by this gate."

$rootScripts = Get-LiveProductRootScripts

Invoke-LiveProductStep `
    -Name "Production L1 aggregate gate" `
    -Owner "hq" `
    -Command "npm run flowchain:production-l1:e2e" `
    -FilePath "npm" `
    -ArgumentList @("run", "flowchain:production-l1:e2e") `
    -Scope "local" `
    -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json") | Out-Null

Invoke-LiveProductStep `
    -Name "Runtime-backed RPC E2E" `
    -Owner "node-rpc" `
    -Command "npm run flowchain:rpc:e2e" `
    -FilePath "npm" `
    -ArgumentList @("run", "flowchain:rpc:e2e") `
    -Scope "local" `
    -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json") | Out-Null

Invoke-LiveProductStep `
    -Name "Wallet account and signing E2E" `
    -Owner "wallet" `
    -Command "npm run flowchain:wallet:e2e" `
    -FilePath "npm" `
    -ArgumentList @("run", "flowchain:wallet:e2e") `
    -Scope "local" `
    -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/wallet-e2e-report.json") | Out-Null

Invoke-LiveProductStep `
    -Name "Wallet transfer E2E" `
    -Owner "wallet/runtime" `
    -Command "npm run flowchain:wallet:transfer:e2e" `
    -FilePath "npm" `
    -ArgumentList @("run", "flowchain:wallet:transfer:e2e") `
    -Scope "local" `
    -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/wallet-transfer/wallet-transfer-e2e-report.json") | Out-Null

Invoke-LiveProductStep `
    -Name "Dashboard wallet build verification" `
    -Owner "dashboard/wallet-apps" `
    -Command "npm run flowchain:dashboard:verify" `
    -FilePath "npm" `
    -ArgumentList @("run", "flowchain:dashboard:verify") `
    -Scope "local" | Out-Null

Invoke-LiveProductStep `
    -Name "Bridge live readiness" `
    -Owner "bridge/ops" `
    -Command "npm run flowchain:bridge:live:check" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"), "-ReportPath", (Join-Path $reportFullDir "bridge-live-readiness-report.json"), "-AllowBlocked") `
    -Scope "live" `
    -AllowFailure `
    -ExpectedReportPath (Join-Path $reportFullDir "bridge-live-readiness-report.json") | Out-Null

$bridgeReadinessPath = Join-Path $reportFullDir "bridge-live-readiness-report.json"
$bridgeReadinessForSkip = Read-LiveProductJsonIfExists -Path $bridgeReadinessPath
if ($bridgeReadinessForSkip -and (Get-JsonPropertyValue -Object $bridgeReadinessForSkip -Name "status" -Fallback "") -ne "passed") {
    $missingForBridge = @((Get-JsonPropertyValue -Object $bridgeReadinessForSkip -Name "missingEnvNames" -Fallback @()) | ForEach-Object { "$_" })
    Add-BlockedLiveProductStep `
        -Name "Live L1 bridge spendability gate" `
        -Owner "bridge/runtime" `
        -Command "npm run flowchain:live-l1-bridge:e2e" `
        -Reason "Skipped because bridge live readiness is $($bridgeReadinessForSkip.status). Missing live env names: $($missingForBridge -join ', ')." `
        -ReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-bridge-e2e/flowchain-live-l1-bridge-e2e-report.json") `
        -EnvNames $missingForBridge
}
else {
    Invoke-LiveProductStep `
        -Name "Live L1 bridge spendability gate" `
        -Owner "bridge/runtime" `
        -Command "npm run flowchain:live-l1-bridge:e2e" `
        -FilePath "npm" `
        -ArgumentList @("run", "flowchain:live-l1-bridge:e2e") `
        -Scope "live" `
        -AllowFailure `
        -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-bridge-e2e/flowchain-live-l1-bridge-e2e-report.json") | Out-Null
}

if ($rootScripts -contains "flowchain:sdk:e2e") {
    Invoke-LiveProductStep `
        -Name "SDK and developer tooling E2E" `
        -Owner "sdk-docs" `
        -Command "npm run flowchain:sdk:e2e" `
        -FilePath "npm" `
        -ArgumentList @("run", "flowchain:sdk:e2e") `
        -Scope "release" | Out-Null
}
else {
    Add-MissingCommandStep -Name "SDK and developer tooling E2E" -Owner "sdk-docs" -Command "npm run flowchain:sdk:e2e" -Reason "Required SDK/devkit gate is not implemented yet."
}

if ($rootScripts -contains "flowchain:live-infra:check") {
    Invoke-LiveProductStep `
        -Name "Live infrastructure public RPC check" `
        -Owner "infra-rpc" `
        -Command "npm run flowchain:live-infra:check" `
        -FilePath "npm" `
        -ArgumentList @("run", "flowchain:live-infra:check") `
        -Scope "live" `
        -AllowFailure | Out-Null
}
else {
    Add-MissingCommandStep -Name "Live infrastructure public RPC check" -Owner "infra-rpc" -Command "npm run flowchain:live-infra:check" -Reason "Required public RPC/service/backup readiness gate is not implemented yet."
}

Invoke-LiveProductStep `
    -Name "No-secret scan" `
    -Owner "security" `
    -Command "npm run flowchain:no-secret:scan" `
    -FilePath "npm" `
    -ArgumentList @("run", "flowchain:no-secret:scan") `
    -Scope "security" `
    -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/no-secret-scan-report.json") | Out-Null

Invoke-LiveProductStep `
    -Name "Unsafe-claim scan" `
    -Owner "security" `
    -Command "node infra/scripts/check-unsafe-claims.mjs" `
    -FilePath "node" `
    -ArgumentList @("infra/scripts/check-unsafe-claims.mjs") `
    -Scope "security" | Out-Null

Invoke-LiveProductStep `
    -Name "Patch whitespace check" `
    -Owner "ops" `
    -Command "git diff --check" `
    -FilePath "git" `
    -ArgumentList @("diff", "--check") `
    -Scope "security" | Out-Null

$productionReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json"
$rpcReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json"
$liveBridgeReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-bridge-e2e/flowchain-live-l1-bridge-e2e-report.json"

$productionReport = Read-LiveProductJsonIfExists -Path $productionReportPath
$rpcReport = Read-LiveProductJsonIfExists -Path $rpcReportPath
$bridgeReadinessReport = Read-LiveProductJsonIfExists -Path $bridgeReadinessPath
$liveBridgeReport = Read-LiveProductJsonIfExists -Path $liveBridgeReportPath

$failedSteps = @($steps | Where-Object { $_.status -eq "failed" })
$blockedSteps = @($steps | Where-Object { $_.status -eq "blocked" })
$liveNotReady = $false

if ($productionReport -and (Get-JsonPropertyValue -Object $productionReport.passFailSummary -Name "liveReadiness" -Fallback "") -ne "passed") {
    $liveNotReady = $true
}
if ($rpcReport -and -not [bool](Get-JsonPropertyValue -Object $rpcReport -Name "publicRpcReady" -Fallback $false)) {
    $liveNotReady = $true
}
if ($bridgeReadinessReport -and (Get-JsonPropertyValue -Object $bridgeReadinessReport -Name "status" -Fallback "") -ne "passed") {
    $liveNotReady = $true
}
if ($liveBridgeReport -and (Get-JsonPropertyValue -Object $liveBridgeReport -Name "status" -Fallback "") -ne "PASS") {
    $liveNotReady = $true
}
if ($blockedSteps.Count -gt 0) {
    $liveNotReady = $true
}

$finalStatus = if ($failedSteps.Count -gt 0) {
    "FAILED"
}
elseif ($liveNotReady) {
    "BLOCKED"
}
else {
    "READY_FOR_CONFIGURED_OWNER_LIVE_TEST"
}

$missingLiveEnv = New-Object System.Collections.ArrayList
foreach ($source in @($productionReport, $rpcReport, $bridgeReadinessReport)) {
    foreach ($propertyName in @("missingEnvNamesForLiveMode", "missingProductionEnvNames", "missingEnvNames")) {
        $values = Get-JsonPropertyValue -Object $source -Name $propertyName -Fallback @()
        foreach ($value in @($values)) {
            if (-not [string]::IsNullOrWhiteSpace("$value") -and -not $missingLiveEnv.Contains("$value")) {
                [void] $missingLiveEnv.Add("$value")
            }
        }
    }
}

$report = [ordered]@{
    schema = "flowchain.live_product.e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $finalStatus
    repoPath = $repoRoot
    npmCacheDir = $npmCacheDir
    git = [ordered]@{
        branch = (& git rev-parse --abbrev-ref HEAD).Trim()
        commit = (& git rev-parse HEAD).Trim()
    }
    commandsRun = @($commandsRun)
    steps = @($steps)
    blockers = @($blockers)
    missingLiveEnvNames = @($missingLiveEnv)
    reports = [ordered]@{
        liveProduct = $reportPath
        productionL1 = $productionReportPath
        rpcE2E = $rpcReportPath
        bridgeLiveReadiness = $bridgeReadinessPath
        liveL1Bridge = $liveBridgeReportPath
    }
    evidence = [ordered]@{
        productionOverall = if ($productionReport) { Get-JsonPropertyValue -Object $productionReport.passFailSummary -Name "overall" -Fallback "unknown" } else { "missing" }
        productionLiveReadiness = if ($productionReport) { Get-JsonPropertyValue -Object $productionReport.passFailSummary -Name "liveReadiness" -Fallback "unknown" } else { "missing" }
        rpcPublicReady = if ($rpcReport) { [bool](Get-JsonPropertyValue -Object $rpcReport -Name "publicRpcReady" -Fallback $false) } else { $false }
        bridgeLiveReadinessStatus = if ($bridgeReadinessReport) { Get-JsonPropertyValue -Object $bridgeReadinessReport -Name "status" -Fallback "missing" } else { "missing" }
        liveBridgeStatus = if ($liveBridgeReport) { Get-JsonPropertyValue -Object $liveBridgeReport -Name "status" -Fallback "missing" } else { "missing" }
        sdkGateImplemented = $rootScripts -contains "flowchain:sdk:e2e"
        infraGateImplemented = $rootScripts -contains "flowchain:live-infra:check"
    }
    noSecrets = $true
    broadcasts = $false
    printsEnvValues = $false
}

Write-FlowChainJson -Path $reportPath -Value $report -Depth 24

@(
    "# FlowChain live-product:e2e Summary",
    "",
    "- Status: $finalStatus",
    "- Report: $reportPath",
    "- Production L1 report: $productionReportPath",
    "- RPC E2E report: $rpcReportPath",
    "- Bridge readiness report: $bridgeReadinessPath",
    "- Live bridge report: $liveBridgeReportPath",
    "- Missing live env names: $((@($missingLiveEnv) | Select-Object -Unique) -join ', ')",
    "",
    "## Blockers",
    $(if ($blockers.Count -eq 0) { "- None." } else { @($blockers | ForEach-Object { "- $($_.code) [$($_.owner)]: $($_.reason)" }) })
) | ForEach-Object {
    if ($_ -is [System.Array]) { $_ } else { "$_" }
} | Set-Content -LiteralPath $summaryPath -Encoding utf8

Write-Host ""
Write-Host "FlowChain live-product:e2e status: $finalStatus"
Write-Host "Report: $reportPath"
Write-Host "Missing live env names: $((@($missingLiveEnv) | Select-Object -Unique) -join ', ')"

if ($finalStatus -eq "FAILED") {
    throw "FlowChain live-product:e2e is FAILED. See $reportPath"
}
if ($finalStatus -ne "READY_FOR_CONFIGURED_OWNER_LIVE_TEST" -and -not $AllowBlocked) {
    throw "FlowChain live-product:e2e is $finalStatus. See $reportPath"
}

if ($null -eq $previousNpmCache) {
    Remove-Item Env:\npm_config_cache -ErrorAction SilentlyContinue
}
else {
    $env:npm_config_cache = $previousNpmCache
}
