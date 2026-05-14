param(
    [switch] $SkipFullSmoke,
    [switch] $AllowIncomplete
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$productRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/product-e2e")

if (Test-Path -LiteralPath $productRoot) {
    Remove-Item -LiteralPath $productRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $productRoot | Out-Null

$checks = [ordered]@{}
$missing = New-Object System.Collections.Generic.List[string]

function Add-ProductCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [bool] $Passed,

        [Parameter(Mandatory = $true)]
        [string] $Owner,

        [Parameter(Mandatory = $true)]
        [string] $Evidence
    )

    $checks[$Name] = [ordered]@{
        passed = $Passed
        owner = $Owner
        evidence = $Evidence
    }

    if (-not $Passed) {
        $missing.Add("$Name ($Owner): $Evidence") | Out-Null
    }
}

if (-not $SkipFullSmoke) {
    Invoke-FlowChainCommand -Label "Run private/local prerequisite full smoke" -FilePath "npm" -ArgumentList @("run", "flowchain:full-smoke")
    Add-ProductCheck -Name "privateLocalFullSmoke" -Passed $true -Owner "integration" -Evidence "npm run flowchain:full-smoke passed"
}
else {
    Add-ProductCheck -Name "privateLocalFullSmoke" -Passed $true -Owner "integration" -Evidence "skipped by caller"
}

$packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$scripts = $packageJson.scripts

$requiredScripts = [ordered]@{
    "flowchain:product-e2e" = "integration"
    "flowchain:node" = "runtime"
    "flowchain:faucet" = "runtime"
    "flowchain:tx" = "runtime"
    "workbench:dev" = "dashboard"
    "control-plane:serve" = "control-plane"
    "bridge:local-credit:smoke" = "bridge"
}

foreach ($scriptName in $requiredScripts.Keys) {
    $exists = $scripts.PSObject.Properties.Name -contains $scriptName
    Add-ProductCheck -Name "script:$scriptName" -Passed $exists -Owner $requiredScripts[$scriptName] -Evidence $(if ($exists) { "script exists" } else { "missing root package script" })
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $runtimeHelp = (& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --help 2>&1) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect flowmemory-devnet help."
    }
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

$requiredRuntimeCommands = [ordered]@{
    "node" = "runtime"
    "submit-tx" = "runtime"
    "faucet" = "runtime"
    "product-demo" = "runtime/token-dex"
    "product-smoke" = "runtime/token-dex"
}

foreach ($commandName in $requiredRuntimeCommands.Keys) {
    $exists = $runtimeHelp -match "(^|\s)$([regex]::Escape($commandName))(\s|$)"
    Add-ProductCheck -Name "runtime-command:$commandName" -Passed $exists -Owner $requiredRuntimeCommands[$commandName] -Evidence $(if ($exists) { "flowmemory-devnet exposes $commandName" } else { "flowmemory-devnet must expose $commandName" })
}

$controlPlaneMethodsPath = Join-Path $repoRoot "services/control-plane/src/types.ts"
$controlPlaneTypes = Get-Content -Raw -LiteralPath $controlPlaneMethodsPath
$requiredControlPlaneMethods = [ordered]@{
    "token_list" = "control-plane"
    "token_get" = "control-plane"
    "token_balance_list" = "control-plane"
    "dex_pool_list" = "control-plane"
    "dex_pool_get" = "control-plane"
    "liquidity_position_list" = "control-plane"
    "swap_list" = "control-plane"
    "product_flow_status" = "control-plane"
}

foreach ($methodName in $requiredControlPlaneMethods.Keys) {
    $exists = $controlPlaneTypes.Contains("`"$methodName`"")
    Add-ProductCheck -Name "control-plane-method:$methodName" -Passed $exists -Owner $requiredControlPlaneMethods[$methodName] -Evidence $(if ($exists) { "method type exists" } else { "method must be implemented and typed" })
}

$dashboardSource = Get-ChildItem -LiteralPath (Join-Path $repoRoot "apps/dashboard/src") -Recurse -File -Include *.tsx,*.ts,*.css |
    ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }
$dashboardText = $dashboardSource -join [Environment]::NewLine
$requiredDashboardSignals = [ordered]@{
    "Launch Token" = "dashboard"
    "Create Pool" = "dashboard"
    "Add Liquidity" = "dashboard"
    "Swap" = "dashboard"
    "Bridge Credit" = "dashboard"
}

foreach ($signalName in $requiredDashboardSignals.Keys) {
    $exists = $dashboardText.Contains($signalName)
    Add-ProductCheck -Name "dashboard-surface:$signalName" -Passed $exists -Owner $requiredDashboardSignals[$signalName] -Evidence $(if ($exists) { "surface text exists" } else { "workbench must expose $signalName user flow" })
}

$reportPath = Join-Path $productRoot "flowchain-product-e2e-report.json"
$report = [ordered]@{
    schema = "flowchain.product_testnet_v1.e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    commit = (& git rev-parse HEAD).Trim()
    status = $(if ($missing.Count -eq 0) { "passed" } else { "incomplete" })
    checks = $checks
    missingCoverage = @($missing)
    readyDefinition = @(
        "wallet funding transfer token launch DEX pool liquidity swap explorer verification",
        "second-computer setup and restart-safe local services",
        "local/testnet bridge funding only until separate production bridge gate"
    )
}

Write-FlowChainJson -Path $reportPath -Value $report -Depth 16

Write-Host ""
Write-Host "FlowChain Product Testnet V1 E2E report: $reportPath"
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Product Testnet V1 is not complete yet. Missing coverage:"
    foreach ($item in $missing) {
        Write-Host "- $item"
    }
    if (-not $AllowIncomplete) {
        throw "FlowChain Product Testnet V1 E2E is incomplete. Rerun with -AllowIncomplete only for coordination reports."
    }
}
else {
    Write-Host "FlowChain Product Testnet V1 E2E passed."
}
