param(
    [string] $ReportDir = "devnet/local/production-l1-e2e"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "production-l1-e2e" | Out-Null
$reportFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportDir)
$logsDir = Join-Path $reportFullDir "logs"
$reportPath = Join-Path $reportFullDir "flowchain-production-l1-e2e-report.json"
$summaryPath = Join-Path $reportFullDir "flowchain-production-l1-e2e-summary.md"

if (Test-Path -LiteralPath $reportFullDir) {
    Remove-Item -LiteralPath $reportFullDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$steps = New-Object System.Collections.ArrayList
$commandsRun = New-Object System.Collections.ArrayList

function Get-SafeStepName {
    param([string] $Name)
    return (($Name -replace '[^A-Za-z0-9_.-]', '-') -replace '-+', '-').Trim("-")
}

function Invoke-ProductionStep {
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

        [ValidateSet("mockPath", "liveReadiness", "liveBroadcast", "none")]
        [string] $Blocks = "mockPath",

        [switch] $AllowFailure,

        [string] $ExpectedReportPath = ""
    )

    $safe = Get-SafeStepName -Name $Name
    $logPath = Join-Path $logsDir "$safe.log"
    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    [void] $commandsRun.Add($Command)

    Write-Host ""
    Write-Host "== $Name =="
    Write-Host $Command

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& $FilePath @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
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
        blocks = $Blocks
        logPath = $logPath
        reportPath = $ExpectedReportPath
        startedAt = $startedAt
        endedAt = $endedAt
        reason = $reason
    }
    [void] $steps.Add($step)

    if ($status -eq "failed") {
        Write-Host "FAILED: $Name"
    }
    elseif ($status -eq "blocked") {
        Write-Host "BLOCKED: $Name"
    }
    else {
        Write-Host "PASSED: $Name"
    }

    return $step
}

function Add-InternalStep {
    param([string] $Name, [string] $Owner, [string] $Command, [string] $Status, [string] $Blocks, [string] $LogPath = "", [string] $ReportPath = "", [string] $Reason = "")
    [void] $commandsRun.Add($Command)
    [void] $steps.Add([ordered]@{
        name = $Name
        owner = $Owner
        command = $Command
        status = $Status
        exitCode = if ($Status -eq "passed") { 0 } else { 1 }
        blocks = $Blocks
        logPath = $LogPath
        reportPath = $ReportPath
        startedAt = (Get-Date).ToUniversalTime().ToString("o")
        endedAt = (Get-Date).ToUniversalTime().ToString("o")
        reason = $Reason
    })
}

function Get-ToolVersion {
    param([string] $Command, [string[]] $VersionArgs = @("--version"))
    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $found) {
        return [ordered]@{ found = $false; version = ""; path = "" }
    }
    try {
        $version = (& $Command @VersionArgs 2>$null | Select-Object -First 1)
    }
    catch {
        $version = "found"
    }
    return [ordered]@{ found = $true; version = "$version"; path = $found.Source }
}

function Get-PortStatus {
    param([int] $Port)
    $connections = @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue)
    return [ordered]@{
        port = $Port
        status = if ($connections.Count -gt 0) { "running" } else { "stopped" }
        owningProcesses = @($connections | Select-Object -ExpandProperty OwningProcess -Unique)
    }
}

function Get-StateFacts {
    param([string] $StatePath)
    $facts = [ordered]@{
        chainId = "unknown"
        genesisHash = "unknown"
        latestHeight = "unknown"
        latestHash = "unknown"
        finalizedHeight = "unknown"
        stateRoot = "unknown"
    }
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return $facts
    }
    try {
        $state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
        if ($state.PSObject.Properties.Name -contains "chainId") { $facts.chainId = "$($state.chainId)" }
        $blocks = @()
        if ($state.PSObject.Properties.Name -contains "blocks") { $blocks = @($state.blocks) }
        if ($blocks.Count -gt 0) {
            $genesis = $blocks[0]
            $latest = $blocks[$blocks.Count - 1]
            foreach ($candidate in @("blockHash", "hash")) {
                if ($genesis.PSObject.Properties.Name -contains $candidate) { $facts.genesisHash = "$($genesis.$candidate)" }
                if ($latest.PSObject.Properties.Name -contains $candidate) { $facts.latestHash = "$($latest.$candidate)" }
            }
            foreach ($candidate in @("height", "blockNumber", "number")) {
                if ($latest.PSObject.Properties.Name -contains $candidate) { $facts.latestHeight = "$($latest.$candidate)" }
            }
        }
        if ($state.PSObject.Properties.Name -contains "finalizedHeight") { $facts.finalizedHeight = "$($state.finalizedHeight)" }
        elseif ($facts.latestHeight -ne "unknown") { $facts.finalizedHeight = $facts.latestHeight }
        if ($state.PSObject.Properties.Name -contains "stateRoot") { $facts.stateRoot = "$($state.stateRoot)" }
    }
    catch {
        return $facts
    }

    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $summaryOutput = (& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $StatePath inspect-state --summary 2>&1) | ForEach-Object { "$_" }
            $summaryExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($summaryExitCode -eq 0) {
            $summaryText = $summaryOutput -join [Environment]::NewLine
            $jsonStart = $summaryText.IndexOf("{")
            $jsonEnd = $summaryText.LastIndexOf("}")
            if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
                return $facts
            }
            $summary = $summaryText.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
            if ($summary.PSObject.Properties.Name -contains "stateRoot") { $facts.stateRoot = "$($summary.stateRoot)" }
            if ($summary.PSObject.Properties.Name -contains "blocks") { $facts.latestHeight = "$($summary.blocks)" }
            if ($summary.PSObject.Properties.Name -contains "chainId") { $facts.chainId = "$($summary.chainId)" }
        }
    }
    catch {
        return $facts
    }
    return $facts
}

function Read-JsonIfExists {
    param([string] $Path)
    if (Test-Path -LiteralPath $Path) {
        try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

Write-Host "FlowChain production-l1:e2e mock-safe gate starting."
Write-Host "Report directory: $reportFullDir"

$parserErrors = New-Object System.Collections.ArrayList
$parserLogPath = Join-Path $logsDir "powershell-parser-check.log"
$changedScripts = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "infra/scripts") -Filter "*.ps1" -File)
foreach ($script in $changedScripts) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath $script.FullName), [ref] $errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        foreach ($error in $errors) {
            [void] $parserErrors.Add("$($script.FullName): $($error.Message) at line $($error.Token.StartLine)")
        }
    }
}
($parserErrors | ForEach-Object { "$_" }) | Set-Content -LiteralPath $parserLogPath -Encoding utf8
if ($parserErrors.Count -eq 0) {
    Add-InternalStep -Name "PowerShell parser checks" -Owner "ops" -Command "PowerShell parser checks for infra/scripts/*.ps1" -Status "passed" -Blocks "mockPath" -LogPath $parserLogPath
}
else {
    Add-InternalStep -Name "PowerShell parser checks" -Owner "ops" -Command "PowerShell parser checks for infra/scripts/*.ps1" -Status "failed" -Blocks "mockPath" -LogPath $parserLogPath -Reason ($parserErrors -join [Environment]::NewLine)
}

$packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$rootScripts = @($packageJson.scripts.PSObject.Properties.Name)
$realValuePilotReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json"
$realValuePilotLogPath = Join-Path $logsDir "Real-value-pilot-coordination-E2E.log"
$missingSubsystemCommands = New-Object System.Collections.ArrayList
foreach ($entry in @(
        [ordered]@{ command = "flowchain:real-value-pilot:contracts"; owner = "contracts"; subsystem = "contracts"; reason = "required for strict live real-value pilot proof; tracked by GitHub issue #133" },
        [ordered]@{ command = "flowchain:real-value-pilot:bridge"; owner = "bridge-relayer"; subsystem = "bridge-relayer"; reason = "required for strict live real-value pilot proof; tracked by GitHub issue #138" },
        [ordered]@{ command = "flowchain:real-value-pilot:runtime"; owner = "chain-runtime"; subsystem = "chain-runtime"; reason = "required for strict live real-value pilot proof; tracked by GitHub issue #134" }
    )) {
    if ($rootScripts -notcontains $entry.command) {
        $entry["logPath"] = $realValuePilotLogPath
        $entry["reportPath"] = $realValuePilotReportPath
        $entry["blocks"] = "liveReadiness"
        $entry["blocksMockPath"] = $false
        $entry["blocksLiveReadiness"] = $true
        $entry["blocksLiveBroadcast"] = $true
        [void] $missingSubsystemCommands.Add($entry)
    }
}

Invoke-ProductionStep -Name "Prerequisite check" -Owner "installer" -Command "npm run flowchain:prereq" -FilePath "npm" -ArgumentList @("run", "flowchain:prereq") -ExpectedReportPath ""
Invoke-ProductionStep -Name "Doctor" -Owner "ops" -Command "npm run flowchain:doctor" -FilePath "npm" -ArgumentList @("run", "flowchain:doctor") -Blocks "none" -AllowFailure -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/doctor/flowchain-doctor-report.json")
Invoke-ProductionStep -Name "Initialize local state" -Owner "runtime/storage" -Command "npm run flowchain:init" -FilePath "npm" -ArgumentList @("run", "flowchain:init")
Invoke-ProductionStep -Name "L1 baseline E2E" -Owner "integration" -Command "npm run flowchain:l1-e2e" -FilePath "npm" -ArgumentList @("run", "flowchain:l1-e2e") -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/full-smoke/flowchain-full-smoke-report.json")
Invoke-ProductionStep -Name "Node start bounded" -Owner "runtime" -Command "npm run flowchain:node:start -- -MaxBlocks 3 -Wait" -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-node-start.ps1"), "-MaxBlocks", "3", "-Wait") -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/node/flowchain-node-start-report.json")
Invoke-ProductionStep -Name "Node status" -Owner "runtime" -Command "npm run flowchain:node:status" -FilePath "npm" -ArgumentList @("run", "flowchain:node:status")
Invoke-ProductionStep -Name "Wallet E2E" -Owner "wallet/crypto" -Command "npm run flowchain:wallet:e2e" -FilePath "npm" -ArgumentList @("run", "flowchain:wallet:e2e") -ExpectedReportPath (Join-Path $reportFullDir "wallet-e2e-report.json")
Invoke-ProductionStep -Name "Wallet transfer E2E" -Owner "wallet/runtime" -Command "npm run flowchain:wallet:transfer:e2e" -FilePath "npm" -ArgumentList @("run", "flowchain:wallet:transfer:e2e") -ExpectedReportPath (Join-Path $reportFullDir "wallet-transfer/wallet-transfer-e2e-report.json")
Invoke-ProductionStep -Name "Product E2E" -Owner "runtime/product" -Command "npm run flowchain:product:e2e -- -SkipFullSmoke" -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-product-e2e.ps1"), "-SkipFullSmoke") -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/product-e2e/flowchain-product-e2e-report.json")
Invoke-ProductionStep -Name "Token and DEX E2E" -Owner "runtime/token-dex" -Command "npm run flowchain:dex:e2e" -FilePath "npm" -ArgumentList @("run", "flowchain:dex:e2e") -ExpectedReportPath (Join-Path $reportFullDir "dex/dex-e2e-report.json")
Invoke-ProductionStep -Name "Bridge mock pilot E2E" -Owner "bridge-relayer" -Command "npm run flowchain:bridge:mock:e2e" -FilePath "npm" -ArgumentList @("run", "flowchain:bridge:mock:e2e")
Invoke-ProductionStep -Name "Real-value pilot coordination E2E" -Owner "hq/ops" -Command "npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete -SkipBaseline" -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-real-value-pilot-e2e.ps1"), "-AllowIncomplete", "-SkipBaseline") -Blocks "liveReadiness" -AllowFailure -ExpectedReportPath $realValuePilotReportPath
Invoke-ProductionStep -Name "Bridge live readiness check" -Owner "bridge/ops" -Command "npm run flowchain:bridge:live:check" -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"), "-AllowBlocked") -Blocks "liveReadiness" -AllowFailure -ExpectedReportPath (Join-Path $reportFullDir "bridge-live-readiness-report.json")
Invoke-ProductionStep -Name "Control-plane smoke" -Owner "control-plane" -Command "npm run flowchain:control-plane:smoke" -FilePath "npm" -ArgumentList @("run", "flowchain:control-plane:smoke")
Invoke-ProductionStep -Name "Dashboard build" -Owner "dashboard" -Command "npm run flowchain:dashboard:build" -FilePath "npm" -ArgumentList @("run", "flowchain:dashboard:build")
Invoke-ProductionStep -Name "Export local state" -Owner "storage" -Command "npm run flowchain:export" -FilePath "npm" -ArgumentList @("run", "flowchain:export")

$mainStatePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/state.json"
$bundlePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/export/flowchain-local-state.zip"
$importedStatePath = Join-Path $reportFullDir "imported-state.json"
$importDir = Join-Path $reportFullDir "imported"
Invoke-ProductionStep -Name "Import local state" -Owner "storage" -Command "npm run flowchain:import -- --BundlePath devnet/local/export/flowchain-local-state.zip -StatePath devnet/local/production-l1-e2e/imported-state.json -Force" -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-import.ps1"), "-BundlePath", $bundlePath, "-StatePath", $importedStatePath, "-ImportDir", $importDir, "-Force")

$originalFacts = Get-StateFacts -StatePath $mainStatePath
$importedFacts = Get-StateFacts -StatePath $importedStatePath
$rootComparePath = Join-Path $reportFullDir "export-import-root-compare.json"
$rootCompareStatus = if ($originalFacts.stateRoot -ne "unknown" -and $originalFacts.stateRoot -eq $importedFacts.stateRoot) { "passed" } else { "failed" }
Write-FlowChainJson -Path $rootComparePath -Value ([ordered]@{
        schema = "flowchain.export_import_root_compare.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = $rootCompareStatus
        originalStateRoot = $originalFacts.stateRoot
        importedStateRoot = $importedFacts.stateRoot
        exportBundle = $bundlePath
        importedStatePath = $importedStatePath
    })
Add-InternalStep -Name "Verify root after restore" -Owner "storage" -Command "compare original/imported state root" -Status $rootCompareStatus -Blocks "mockPath" -ReportPath $rootComparePath -Reason $(if ($rootCompareStatus -eq "passed") { "" } else { "state roots did not match" })

Invoke-ProductionStep -Name "Restart recovery" -Owner "runtime/storage" -Command "npm run flowchain:restart:verify" -FilePath "npm" -ArgumentList @("run", "flowchain:restart:verify") -ExpectedReportPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/node-smoke/one-node-smoke-report.json")
Invoke-ProductionStep -Name "No-secret scan" -Owner "security" -Command "npm run flowchain:no-secret:scan" -FilePath "npm" -ArgumentList @("run", "flowchain:no-secret:scan") -ExpectedReportPath (Join-Path $reportFullDir "no-secret-scan-report.json")
Invoke-ProductionStep -Name "Unsafe-claim scan" -Owner "security" -Command "node infra/scripts/check-unsafe-claims.mjs" -FilePath "node" -ArgumentList @("infra/scripts/check-unsafe-claims.mjs")
Invoke-ProductionStep -Name "Patch whitespace check" -Owner "ops" -Command "git diff --check" -FilePath "git" -ArgumentList @("diff", "--check")
Invoke-ProductionStep -Name "Evidence export" -Owner "ops/security" -Command "npm run flowchain:emergency:export-evidence" -FilePath "npm" -ArgumentList @("run", "flowchain:emergency:export-evidence") -ExpectedReportPath (Join-Path $reportFullDir "evidence/flowchain-production-l1-evidence-export-report.json")

$stateFacts = Get-StateFacts -StatePath $mainStatePath
$bridgeLiveReport = Read-JsonIfExists -Path (Join-Path $reportFullDir "bridge-live-readiness-report.json")
$productReport = Read-JsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/product-e2e/flowchain-product-e2e-report.json")
$walletTransferReport = Read-JsonIfExists -Path (Join-Path $reportFullDir "wallet-transfer/wallet-transfer-e2e-report.json")
$dexReport = Read-JsonIfExists -Path (Join-Path $reportFullDir "dex/dex-e2e-report.json")
$evidenceReport = Read-JsonIfExists -Path (Join-Path $reportFullDir "evidence/flowchain-production-l1-evidence-export-report.json")
$restartReport = Read-JsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/node-smoke/one-node-smoke-report.json")

$mockFailures = @($steps | Where-Object { $_.blocks -eq "mockPath" -and $_.status -ne "passed" })
$liveFailed = @($steps | Where-Object { $_.blocks -eq "liveReadiness" -and $_.status -eq "failed" })
$liveBlocked = @($steps | Where-Object { $_.blocks -eq "liveReadiness" -and $_.status -ne "passed" })
$overallStatus = if ($mockFailures.Count -gt 0) {
    "failed"
}
elseif ($liveFailed.Count -gt 0) {
    "failed"
}
elseif ($liveBlocked.Count -gt 0 -or $missingSubsystemCommands.Count -gt 0) {
    "passed-with-live-blockers"
}
else {
    "passed"
}

$failureBlockerDetails = New-Object System.Collections.ArrayList
foreach ($step in @($steps | Where-Object { $_.status -ne "passed" })) {
    [void] $failureBlockerDetails.Add([ordered]@{
            subsystem = $step.owner
            owner = $step.owner
            command = $step.command
            status = $step.status
            logPath = $step.logPath
            reportPath = $step.reportPath
            blocks = $step.blocks
            blocksMockPath = ($step.blocks -eq "mockPath")
            blocksLiveReadiness = ($step.blocks -eq "liveReadiness")
            blocksLiveBroadcast = ($step.blocks -eq "liveBroadcast" -or $step.blocks -eq "liveReadiness")
            reason = $step.reason
        })
}
foreach ($missingCommand in @($missingSubsystemCommands)) {
    [void] $failureBlockerDetails.Add([ordered]@{
            subsystem = $missingCommand.subsystem
            owner = $missingCommand.owner
            command = $missingCommand.command
            status = "blocked"
            logPath = $missingCommand.logPath
            reportPath = $missingCommand.reportPath
            blocks = $missingCommand.blocks
            blocksMockPath = $missingCommand.blocksMockPath
            blocksLiveReadiness = $missingCommand.blocksLiveReadiness
            blocksLiveBroadcast = $missingCommand.blocksLiveBroadcast
            reason = $missingCommand.reason
        })
}
if ($bridgeLiveReport -and $bridgeLiveReport.status -ne "passed") {
    $bridgeStep = @($steps | Where-Object { $_.name -eq "Bridge live readiness check" } | Select-Object -First 1)
    foreach ($problem in @($bridgeLiveReport.problems)) {
        [void] $failureBlockerDetails.Add([ordered]@{
                subsystem = "bridge/ops"
                owner = "bridge/ops"
                command = "npm run flowchain:bridge:live:check"
                status = $bridgeLiveReport.status
                envName = $problem.envName
                logPath = if ($bridgeStep) { $bridgeStep.logPath } else { "" }
                reportPath = (Join-Path $reportFullDir "bridge-live-readiness-report.json")
                blocks = "liveReadiness"
                blocksMockPath = $false
                blocksLiveReadiness = $true
                blocksLiveBroadcast = $true
                reason = $problem.reason
            })
    }
}

$emergencyCommands = @(
    "npm run flowchain:emergency:stop-local",
    "npm run flowchain:bridge:emergency-stop",
    "npm run flowchain:emergency:pause-bridge",
    "npm run flowchain:emergency:export-evidence",
    "npm run flowchain:emergency:print-recovery"
)
$restartCommands = @(
    "npm run flowchain:node:restart",
    "npm run flowchain:node:status",
    "npm run control-plane:serve",
    "npm run workbench:dev"
)

$report = [ordered]@{
    schema = "flowchain.production_l1.e2e_report.v0"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    repoPath = $repoRoot
    git = [ordered]@{
        branch = (& git rev-parse --abbrev-ref HEAD).Trim()
        commit = (& git rev-parse HEAD).Trim()
    }
    os = [ordered]@{
        platform = [System.Environment]::OSVersion.Platform.ToString()
        version = [System.Environment]::OSVersion.VersionString
        shell = "PowerShell"
    }
    toolVersions = [ordered]@{
        git = Get-ToolVersion -Command "git"
        node = Get-ToolVersion -Command "node"
        npm = Get-ToolVersion -Command "npm"
        cargo = Get-ToolVersion -Command "cargo"
        rustc = Get-ToolVersion -Command "rustc"
        forge = Get-ToolVersion -Command "forge"
        cast = Get-ToolVersion -Command "cast"
        python = Get-ToolVersion -Command "python" -VersionArgs @("--version")
    }
    portsUsed = @(
        Get-PortStatus -Port 8787
        Get-PortStatus -Port 5173
    )
    localUrls = [ordered]@{
        controlPlaneHealth = "http://127.0.0.1:8787/health"
        controlPlaneState = "http://127.0.0.1:8787/state"
        dashboard = "http://127.0.0.1:5173/"
    }
    dataDirectory = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local")
    chainId = $stateFacts.chainId
    genesisHash = $stateFacts.genesisHash
    latestHeight = $stateFacts.latestHeight
    latestHash = $stateFacts.latestHash
    finalizedHeight = $stateFacts.finalizedHeight
    stateRoot = $stateFacts.stateRoot
    walletE2EStatus = (@($steps | Where-Object { $_.name -eq "Wallet E2E" })[0]).status
    transferE2EStatus = (@($steps | Where-Object { $_.name -eq "Wallet transfer E2E" })[0]).status
    tokenE2EStatus = if ($dexReport) { $dexReport.tokenStatus } else { "unknown" }
    dexE2EStatus = if ($dexReport) { $dexReport.dexStatus } else { "unknown" }
    productE2EStatus = if ($productReport) { $productReport.status } else { (@($steps | Where-Object { $_.name -eq "Product E2E" })[0]).status }
    bridgeMockStatus = (@($steps | Where-Object { $_.name -eq "Bridge mock pilot E2E" })[0]).status
    bridgeLiveReadinessStatus = if ($bridgeLiveReport) { $bridgeLiveReport.status } else { (@($steps | Where-Object { $_.name -eq "Bridge live readiness check" })[0]).status }
    rpcSmokeStatus = (@($steps | Where-Object { $_.name -eq "Control-plane smoke" })[0]).status
    dashboardBuildOrBrowserStatus = (@($steps | Where-Object { $_.name -eq "Dashboard build" })[0]).status
    exportImportStatus = $rootCompareStatus
    restartRecoveryStatus = if ($restartReport) { "passed" } else { (@($steps | Where-Object { $_.name -eq "Restart recovery" })[0]).status }
    noSecretScanStatus = (@($steps | Where-Object { $_.name -eq "No-secret scan" })[0]).status
    unsafeClaimScanStatus = (@($steps | Where-Object { $_.name -eq "Unsafe-claim scan" })[0]).status
    missingEnvNamesForLiveMode = if ($bridgeLiveReport) { @($bridgeLiveReport.missingEnvNames) } else { @() }
    missingSubsystemCommands = @($missingSubsystemCommands)
    failureBlockerDetails = @($failureBlockerDetails)
    commandList = @($commandsRun)
    subsystemSteps = @($steps)
    localLogPaths = [ordered]@{
        productionE2ELogs = $logsDir
        nodeLogs = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/node/logs")
        bridgeLogs = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/out")
        apiLogs = "Use the PowerShell window running npm run control-plane:serve; final smoke logs are under $logsDir"
        dashboardBuildLog = Join-Path $logsDir "Dashboard-build.log"
    }
    healthEndpoint = "http://127.0.0.1:8787/health"
    reportPaths = [ordered]@{
        production = $reportPath
        summary = $summaryPath
        l1Baseline = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/full-smoke/flowchain-full-smoke-report.json")
        smoke = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/smoke/flowchain-smoke-report.json")
        product = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/product-e2e/flowchain-product-e2e-report.json")
        bridgeLiveReadiness = (Join-Path $reportFullDir "bridge-live-readiness-report.json")
        exportImportRootCompare = $rootComparePath
        restart = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/node-smoke/one-node-smoke-report.json")
        evidence = if ($evidenceReport) { $evidenceReport.bundlePath } else { "" }
    }
    restartCommands = $restartCommands
    emergencyCommands = $emergencyCommands
    evidencePaths = [ordered]@{
        bundle = if ($evidenceReport) { $evidenceReport.bundlePath } else { "" }
        report = (Join-Path $reportFullDir "evidence/flowchain-production-l1-evidence-export-report.json")
        exportBundle = $bundlePath
    }
    passFailSummary = [ordered]@{
        overall = $overallStatus
        mockPath = if ($mockFailures.Count -eq 0) { "passed" } else { "failed" }
        liveReadiness = if ($liveBlocked.Count -eq 0 -and $missingSubsystemCommands.Count -eq 0) { "passed" } else { "blocked" }
        liveBroadcast = "not-run; requires explicit operator acknowledgement and owner-supplied live env"
        failedMockSteps = @($mockFailures | ForEach-Object { $_.name })
        blockedLiveSteps = @($liveBlocked | ForEach-Object { $_.name })
    }
}

Write-FlowChainJson -Path $reportPath -Value $report -Depth 24

$summary = @(
    "# FlowChain production-l1:e2e Summary",
    "",
    "- Status: $overallStatus",
    "- Local dashboard URL: http://127.0.0.1:5173/",
    "- Control-plane health URL: http://127.0.0.1:8787/health",
    "- Data directory: $($report.dataDirectory)",
    "- Final report: $reportPath",
    "- Evidence bundle: $($report.evidencePaths.bundle)",
    "- State root: $($report.stateRoot)",
    "- Live readiness command: npm run flowchain:bridge:live:check",
    "- Missing live env names: $((@($report.missingEnvNamesForLiveMode) | Select-Object -Unique) -join ', ')",
    "",
    "## Emergency Commands",
    ($emergencyCommands | ForEach-Object { "- $_" }),
    "",
    "## Blockers",
    $(if ($missingSubsystemCommands.Count -eq 0 -and $liveBlocked.Count -eq 0) { "- None for live readiness." } else { @($missingSubsystemCommands | ForEach-Object { "- $($_.command) [$($_.owner)]: $($_.reason)" }) + @($liveBlocked | ForEach-Object { "- $($_.name): $($_.status)" }) })
) | ForEach-Object {
    if ($_ -is [System.Array]) { $_ } else { "$_" }
} | Set-Content -LiteralPath $summaryPath -Encoding utf8

Write-Host ""
Write-Host "FlowChain production-l1:e2e status: $overallStatus"
Write-Host "Dashboard URL: http://127.0.0.1:5173/"
Write-Host "Data directory: $($report.dataDirectory)"
Write-Host "Final report: $reportPath"
Write-Host "Evidence bundle: $($report.evidencePaths.bundle)"
Write-Host "Bridge live readiness command: npm run flowchain:bridge:live:check"
Write-Host "Required live env names: $((@($report.missingEnvNamesForLiveMode) | Select-Object -Unique) -join ', ')"
Write-Host "Emergency stop commands:"
foreach ($command in $emergencyCommands) {
    Write-Host "- $command"
}

if ($overallStatus -eq "failed") {
    throw "FlowChain production-l1:e2e failed. See $reportPath"
}
