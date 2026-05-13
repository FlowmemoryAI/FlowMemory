param(
    [switch] $SkipMergedSmoke,
    [switch] $SkipDashboardBuild,
    [switch] $SkipHardware,
    [switch] $AllowIncomplete
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Test-NpmScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackagePath,

        [Parameter(Mandatory = $true)]
        [string] $ScriptName
    )

    if (-not (Test-Path -LiteralPath $PackagePath)) {
        return $false
    }

    $package = Get-Content -Raw -LiteralPath $PackagePath | ConvertFrom-Json
    if (-not $package.PSObject.Properties.Name.Contains("scripts")) {
        return $false
    }

    return $package.scripts.PSObject.Properties.Name.Contains($ScriptName)
}

function New-Requirement {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Area,

        [Parameter(Mandatory = $true)]
        [string] $OwnerIssue,

        [Parameter(Mandatory = $true)]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [string] $PackagePath,

        [Parameter(Mandatory = $true)]
        [string] $ScriptName,

        [Parameter(Mandatory = $true)]
        [string] $Acceptance
    )

    $exists = Test-NpmScript -PackagePath $PackagePath -ScriptName $ScriptName
    return [ordered]@{
        area = $Area
        ownerIssue = $OwnerIssue
        command = $Command
        status = $(if ($exists) { "command-present" } else { "missing-command" })
        acceptance = $Acceptance
    }
}

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$reportRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/smoke")
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null

$currentSmokeStatus = "skipped"
if (-not $SkipMergedSmoke) {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-smoke.ps1")
    )
    if ($SkipDashboardBuild) {
        $args += "-SkipDashboardBuild"
    }
    if ($SkipHardware) {
        $args += "-SkipHardware"
    }

    & powershell @args
    if ($LASTEXITCODE -ne 0) {
        throw "Merged-surface smoke failed before full-L1 coverage checks."
    }
    $currentSmokeStatus = "passed"
}

$rootPackage = Join-Path $repoRoot "package.json"
$cryptoPackage = Join-Path $repoRoot "crypto/package.json"
$dashboardPackage = Join-Path $repoRoot "apps/dashboard/package.json"

$requirements = @(
    (New-Requirement -Area "chain" -OwnerIssue "#99" -Command "npm run flowchain:node" -PackagePath $rootPackage -ScriptName "flowchain:node" -Acceptance "Start a long-running local node that produces blocks and persists state."),
    (New-Requirement -Area "chain" -OwnerIssue "#99" -Command "npm run flowchain:node:smoke" -PackagePath $rootPackage -ScriptName "flowchain:node:smoke" -Acceptance "Prove node restart, transaction inclusion, export/import, and at least 10 blocks."),
    (New-Requirement -Area "chain" -OwnerIssue "#99" -Command "npm run flowchain:multi-node:smoke" -PackagePath $rootPackage -ScriptName "flowchain:multi-node:smoke" -Acceptance "Prove two local processes exchange or deterministically reconcile state, or explicitly gate LAN mode."),
    (New-Requirement -Area "chain" -OwnerIssue "#99" -Command "npm run flowchain:tx" -PackagePath $rootPackage -ScriptName "flowchain:tx" -Acceptance "Submit signed/local test transactions into the runtime intake path."),
    (New-Requirement -Area "chain" -OwnerIssue "#99" -Command "npm run flowchain:faucet" -PackagePath $rootPackage -ScriptName "flowchain:faucet" -Acceptance "Create local test-unit balance records without tokenomics claims."),
    (New-Requirement -Area "crypto" -OwnerIssue "#100" -Command "npm run wallet:create --prefix crypto" -PackagePath $cryptoPackage -ScriptName "wallet:create" -Acceptance "Create an encrypted local test wallet or vault without committing secrets."),
    (New-Requirement -Area "crypto" -OwnerIssue "#100" -Command "npm run wallet:sign --prefix crypto" -PackagePath $cryptoPackage -ScriptName "wallet:sign" -Acceptance "Sign canonical local transaction envelopes."),
    (New-Requirement -Area "crypto" -OwnerIssue "#100" -Command "npm run wallet:verify --prefix crypto" -PackagePath $cryptoPackage -ScriptName "wallet:verify" -Acceptance "Verify local transaction envelopes and reject negative vectors."),
    (New-Requirement -Area "control-plane" -OwnerIssue "#101" -Command "npm run control-plane:smoke" -PackagePath $rootPackage -ScriptName "control-plane:smoke" -Acceptance "Query every lifecycle object and scan API responses for secrets."),
    (New-Requirement -Area "dashboard" -OwnerIssue "#102" -Command "npm run build --prefix apps/dashboard" -PackagePath $dashboardPackage -ScriptName "build" -Acceptance "Build the live workbench that consumes control-plane health and state."),
    (New-Requirement -Area "bridge" -OwnerIssue "#104" -Command "npm run bridge:mock" -PackagePath $rootPackage -ScriptName "bridge:mock" -Acceptance "Produce deterministic mock bridge observations."),
    (New-Requirement -Area "bridge" -OwnerIssue "#104" -Command "npm run bridge:sepolia:observe" -PackagePath $rootPackage -ScriptName "bridge:sepolia:observe" -Acceptance "Observe explicit Base Sepolia bridge deposits without private keys."),
    (New-Requirement -Area "bridge" -OwnerIssue "#104" -Command "npm run bridge:local-credit:smoke" -PackagePath $rootPackage -ScriptName "bridge:local-credit:smoke" -Acceptance "Apply or hand off a BridgeCredit to the local runtime with replay protection."),
    (New-Requirement -Area "hardware" -OwnerIssue "#105" -Command "hardware simulator fixture validation" -PackagePath $rootPackage -ScriptName "flowchain:hardware:smoke" -Acceptance "Validate optional operator-signal fixture ingestion without requiring physical devices."),
    (New-Requirement -Area "ops" -OwnerIssue "#108" -Command "npm run flowchain:full-smoke" -PackagePath $rootPackage -ScriptName "flowchain:full-smoke" -Acceptance "Run this wrapper as the final end-to-end acceptance gate.")
)

$missing = @($requirements | Where-Object { $_.status -ne "command-present" })
$coverageGaps = @(
    "long-running local node runtime",
    "signed transaction envelope submitted and included",
    "local wallet create/sign/verify path",
    "native AgentAccount, ModelPassport, MemoryCell, Challenge, and FinalityReceipt lifecycle evidence",
    "full control-plane live-node query coverage",
    "workbench live-state inspection evidence",
    "bridge local credit smoke",
    "deterministic full export/import replay root comparison"
)

$reportPath = Join-Path $reportRoot "flowchain-full-smoke-report.json"
$report = [ordered]@{
    schema = "flowchain.private_testnet.full_smoke_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    currentMergedSmoke = $currentSmokeStatus
    fullAcceptance = ($missing.Count -eq 0)
    requirements = $requirements
    missingCommands = @($missing | ForEach-Object { $_.command })
    coverageGaps = $coverageGaps
    issueMap = [ordered]@{
        chain = "#99"
        crypto = "#100"
        controlPlane = "#101"
        dashboard = "#102"
        contracts = "#103"
        bridge = "#104"
        hardware = "#105"
        research = "#106"
        hq = "#107"
        fullSmoke = "#108"
    }
}
Write-FlowChainJson -Path $reportPath -Value $report

Write-Host ""
Write-Host "FlowChain full-smoke coverage report: $reportPath"
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Full private/local L1 smoke is not complete yet. Missing required command coverage:"
    foreach ($item in $missing) {
        Write-Host "- [$($item.area)] $($item.command) ($($item.ownerIssue)): $($item.acceptance)"
    }
    Write-Host ""
    Write-Host "Current merged-surface smoke status: $currentSmokeStatus"
    Write-Host "Run with -AllowIncomplete only when validating this temporary blocker-report wrapper."

    if (-not $AllowIncomplete) {
        throw "FlowChain full-smoke is incomplete. See $reportPath and issues #99-#108."
    }
}
else {
    Write-Host "FlowChain full-smoke command coverage is present. Subsystem smoke commands can now be promoted into a passing end-to-end gate."
}
