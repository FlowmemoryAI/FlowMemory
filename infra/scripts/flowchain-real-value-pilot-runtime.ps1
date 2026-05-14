param(
    [string] $HandoffPath = "",
    [string] $RunDir = "devnet/local/real-value-pilot-e2e"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "real-value-pilot-e2e" | Out-Null

$bridgeProofHandoffPath = "services/bridge-relayer/out/real-value-pilot-e2e/bridge-runtime-handoff.json"
$fixtureHandoffPath = "fixtures/bridge/local-runtime-bridge-handoff.json"
$handoffSource = "explicit"
if ([string]::IsNullOrWhiteSpace($HandoffPath)) {
    $bridgeProofHandoffFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $bridgeProofHandoffPath)
    if (Test-Path -LiteralPath $bridgeProofHandoffFullPath) {
        $HandoffPath = $bridgeProofHandoffPath
        $handoffSource = "bridge-proof-output"
    }
    else {
        $HandoffPath = $fixtureHandoffPath
        $handoffSource = "committed-fixture"
    }
}

$runFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RunDir)
$handoffFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $HandoffPath)
$localRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local")
$runComparable = [System.IO.Path]::GetFullPath($runFullDir).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$localComparable = [System.IO.Path]::GetFullPath($localRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$localPrefix = $localComparable + [System.IO.Path]::DirectorySeparatorChar
if ($runComparable -eq $localComparable -or -not $runComparable.StartsWith($localPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clear runtime proof run directory outside a devnet/local child: $runFullDir"
}

if (-not (Test-Path -LiteralPath $handoffFullPath)) {
    throw "Bridge handoff file does not exist: $handoffFullPath"
}

if (Test-Path -LiteralPath $runFullDir) {
    Remove-Item -LiteralPath $runFullDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $runFullDir | Out-Null

$statePath = Join-Path $runFullDir "runtime-state.json"
$productOutDir = Join-Path $runFullDir "product-smoke"
$handoffExportDir = Join-Path $runFullDir "handoff-export"
$snapshotPath = Join-Path $runFullDir "snapshot.json"
$importedStatePath = Join-Path $runFullDir "imported-state.json"

$checks = [ordered]@{}
$missing = New-Object System.Collections.Generic.List[string]

function Add-PilotCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [bool] $Passed,

        [Parameter(Mandatory = $true)]
        [string] $Evidence
    )

    $checks[$Name] = [ordered]@{
        passed = $Passed
        evidence = $Evidence
    }

    if (-not $Passed) {
        $missing.Add("${Name}: $Evidence") | Out-Null
    }
}

function Invoke-FlowChainJsonCargo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Label,

        [Parameter(Mandatory = $true)]
        [string[]] $RuntimeArgs
    )

    Write-Host ""
    Write-Host "== $Label =="

    $previousErrorActionPreference = $ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        $output = (& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- @RuntimeArgs 2>&1) -join [Environment]::NewLine
        $exitCode = $LASTEXITCODE
    }
    finally {
        $script:ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode.`n$output"
    }

    $jsonStart = $output.IndexOf("{")
    $jsonEnd = $output.LastIndexOf("}")
    if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
        throw "$Label did not emit JSON output.`n$output"
    }

    return $output.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
}

function Get-ReceiptRows {
    param(
        [Parameter(Mandatory = $true)]
        [object] $State
    )

    $rows = New-Object System.Collections.ArrayList
    foreach ($block in @($State.blocks)) {
        if ($null -eq $block.receipts) {
            continue
        }
        foreach ($receipt in @($block.receipts)) {
            if ($null -eq $receipt) {
                continue
            }
            $rows.Add($receipt) | Out-Null
        }
    }

    return @($rows)
}

$handoff = Get-Content -Raw -LiteralPath $handoffFullPath | ConvertFrom-Json
if ($handoff.schema -ne "flowmemory.bridge_runtime_handoff.v0") {
    throw "Unsupported bridge handoff schema: $($handoff.schema)"
}

$handoffCredits = @($handoff.credits)
if ($handoffCredits.Count -lt 1) {
    throw "Bridge handoff contains no credits: $handoffFullPath"
}

$pilotCredit = $handoffCredits[0]
$pilotSource = $pilotCredit.source
$pilotCreditId = [string] $pilotCredit.creditId
$pilotReplayKey = [string] $pilotCredit.replayKey
$pilotRecipient = [string] $pilotCredit.flowchainRecipient
$pilotAmount = [UInt64] $pilotCredit.amount
$pilotSourceChainId = [UInt64] $pilotSource.chainId
$pilotSourceContract = [string] $pilotSource.contract
$pilotTxHash = [string] $pilotSource.txHash
$pilotLogIndex = [UInt64] $pilotSource.logIndex

$expectedBridgeAccountId = ""

Invoke-FlowChainJsonCargo -Label "Run product smoke setup" -RuntimeArgs @(
    "--state",
    $statePath,
    "product-smoke",
    "--out-dir",
    $productOutDir
) | Out-Null

$firstQueue = Invoke-FlowChainJsonCargo -Label "Queue pilot bridge handoff" -RuntimeArgs @(
    "--state",
    $statePath,
    "bridge-handoff",
    "--handoff",
    $handoffFullPath,
    "--authorized-by",
    "operator:bridge:pilot",
    "--direct"
)
$creditTxId = [string] @($firstQueue.queued)[-1]

Invoke-FlowChainJsonCargo -Label "Include bridge credit in block" -RuntimeArgs @(
    "--state",
    $statePath,
    "run-block"
) | Out-Null

$stateAfterCredit = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
$receiptsAfterCredit = Get-ReceiptRows -State $stateAfterCredit
$appliedCreditReceipts = @($receiptsAfterCredit | Where-Object { $_.txId -eq $creditTxId -and $_.status -eq "applied" })
$bridgeCreditProperty = $stateAfterCredit.bridgeCredits.PSObject.Properties[$pilotCreditId]
$bridgeCreditRecord = if ($null -eq $bridgeCreditProperty) { $null } else { $bridgeCreditProperty.Value }
$expectedBridgeAccountId = if ($null -eq $bridgeCreditRecord) { "missing" } else { [string] $bridgeCreditRecord.accountId }
$bridgeBalanceProperty = $stateAfterCredit.localTestUnitBalances.PSObject.Properties[$expectedBridgeAccountId]
$bridgeBalance = if ($null -eq $bridgeBalanceProperty) { $null } else { $bridgeBalanceProperty.Value }
$bridgeBalanceUnits = if ($null -eq $bridgeBalance) { "missing" } else { [string] $bridgeBalance.units }

Add-PilotCheck -Name "bridge-credit-included-once" -Passed ($appliedCreditReceipts.Count -eq 1) -Evidence "credit transaction $creditTxId applied $($appliedCreditReceipts.Count) time(s)"
Add-PilotCheck -Name "bridge-credit-state-recorded" -Passed ($stateAfterCredit.bridgeCredits.PSObject.Properties.Name -contains $pilotCreditId) -Evidence "bridge credit id $pilotCreditId present in state"
Add-PilotCheck -Name "bridge-receipt-state-recorded" -Passed ($stateAfterCredit.bridgeCreditReceipts.PSObject.Properties.Name -contains $pilotCreditId) -Evidence "bridge receipt id $pilotCreditId present in state"
Add-PilotCheck -Name "bridge-local-balance-credited" -Passed ($null -ne $bridgeBalance -and ([UInt64] $bridgeBalance.units) -eq $pilotAmount) -Evidence "local bridge account $expectedBridgeAccountId balance is $bridgeBalanceUnits"
Add-PilotCheck -Name "bridge-replay-index-recorded" -Passed ($stateAfterCredit.bridgeReplayIndex.PSObject.Properties.Name -contains $pilotReplayKey) -Evidence "replay key $pilotReplayKey present in state"

$secondQueue = Invoke-FlowChainJsonCargo -Label "Queue duplicate bridge handoff" -RuntimeArgs @(
    "--state",
    $statePath,
    "bridge-handoff",
    "--handoff",
    $handoffFullPath,
    "--authorized-by",
    "operator:bridge:pilot",
    "--direct"
)
$duplicateCreditTxId = [string] @($secondQueue.queued)[-1]

Invoke-FlowChainJsonCargo -Label "Reject duplicate bridge credit in block" -RuntimeArgs @(
    "--state",
    $statePath,
    "run-block"
) | Out-Null

$stateAfterReplay = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
$receiptsAfterReplay = Get-ReceiptRows -State $stateAfterReplay
$rejectedDuplicateReceipts = @($receiptsAfterReplay | Where-Object {
    $_.txId -eq $duplicateCreditTxId -and
    $_.status -eq "rejected" -and
    [string] $_.error -like "*bridge replay key is already consumed*"
})
$allAppliedCreditReceipts = @($receiptsAfterReplay | Where-Object { $_.txId -eq $creditTxId -and $_.status -eq "applied" })

Add-PilotCheck -Name "bridge-replay-rejected-with-evidence" -Passed ($rejectedDuplicateReceipts.Count -ge 1) -Evidence "duplicate transaction $duplicateCreditTxId rejected with replay evidence $($rejectedDuplicateReceipts.Count) time(s)"
Add-PilotCheck -Name "bridge-credit-still-included-once-after-replay" -Passed ($allAppliedCreditReceipts.Count -eq 1) -Evidence "original credit transaction $creditTxId applied $($allAppliedCreditReceipts.Count) time(s) after replay"
$bridgeCreditCountAfterReplay = @($stateAfterReplay.bridgeCredits.PSObject.Properties).Count
Add-PilotCheck -Name "bridge-credit-count-stable-after-replay" -Passed ($bridgeCreditCountAfterReplay -eq 1) -Evidence "bridge credit count is $bridgeCreditCountAfterReplay"

$receiptById = Invoke-FlowChainJsonCargo -Label "Query bridge receipt by id" -RuntimeArgs @(
    "--state",
    $statePath,
    "bridge-receipt",
    "--receipt-id",
    $pilotCreditId
)
Add-PilotCheck -Name "bridge-receipt-by-id" -Passed ([bool] $receiptById.found -and $receiptById.receipt.receiptId -eq $pilotCreditId) -Evidence "receipt lookup by id returned found=$($receiptById.found)"
Add-PilotCheck -Name "bridge-credit-local-boundary" -Passed ([bool] $receiptById.bridgeCredit.localOnly -and [bool] $receiptById.bridgeCredit.noValue -and -not [bool] $receiptById.bridgeCredit.productionReady) -Evidence "credit localOnly=$($receiptById.bridgeCredit.localOnly), noValue=$($receiptById.bridgeCredit.noValue), productionReady=$($receiptById.bridgeCredit.productionReady)"
Add-PilotCheck -Name "bridge-receipt-local-boundary" -Passed ([bool] $receiptById.receipt.localOnly -and -not [bool] $receiptById.receipt.productionReady) -Evidence "receipt localOnly=$($receiptById.receipt.localOnly), productionReady=$($receiptById.receipt.productionReady)"

$missingReceiptId = "receipt:bridge:pilot:missing"
$receiptByWrongId = Invoke-FlowChainJsonCargo -Label "Query bridge receipt by wrong id" -RuntimeArgs @(
    "--state",
    $statePath,
    "bridge-receipt",
    "--receipt-id",
    $missingReceiptId
)
Add-PilotCheck -Name "bridge-receipt-wrong-id-not-found" -Passed (-not [bool] $receiptByWrongId.found) -Evidence "wrong receipt id returned found=$($receiptByWrongId.found)"

$receiptByEvent = Invoke-FlowChainJsonCargo -Label "Query bridge receipt by Base event reference" -RuntimeArgs @(
    "--state",
    $statePath,
    "bridge-receipt",
    "--source-chain-id",
    ([string] $pilotSourceChainId),
    "--source-contract",
    $pilotSourceContract,
    "--tx-hash",
    $pilotTxHash,
    "--log-index",
    ([string] $pilotLogIndex)
)
Add-PilotCheck -Name "bridge-receipt-by-base-event" -Passed ([bool] $receiptByEvent.found -and $receiptByEvent.receipt.receiptId -eq $pilotCreditId) -Evidence "event lookup returned receiptId=$($receiptByEvent.receipt.receiptId)"

$wrongLogIndex = [string] ($pilotLogIndex + 1)
$receiptByWrongEvent = Invoke-FlowChainJsonCargo -Label "Query bridge receipt by wrong Base event reference" -RuntimeArgs @(
    "--state",
    $statePath,
    "bridge-receipt",
    "--source-chain-id",
    ([string] $pilotSourceChainId),
    "--source-contract",
    $pilotSourceContract,
    "--tx-hash",
    $pilotTxHash,
    "--log-index",
    $wrongLogIndex
)
Add-PilotCheck -Name "bridge-receipt-wrong-base-event-not-found" -Passed (-not [bool] $receiptByWrongEvent.found) -Evidence "wrong event logIndex=$wrongLogIndex returned found=$($receiptByWrongEvent.found)"

Invoke-FlowChainJsonCargo -Label "Restart runtime for one block" -RuntimeArgs @(
    "--state",
    $statePath,
    "start",
    "--blocks",
    "1"
) | Out-Null

$restartSummary = Invoke-FlowChainJsonCargo -Label "Inspect restarted state" -RuntimeArgs @(
    "--state",
    $statePath,
    "inspect-state",
    "--summary"
)

Add-PilotCheck -Name "restart-preserves-token-state" -Passed ([int] $restartSummary.tokenDefinitions -ge 1) -Evidence "tokenDefinitions=$($restartSummary.tokenDefinitions)"
Add-PilotCheck -Name "restart-preserves-dex-state" -Passed ([int] $restartSummary.dexPools -ge 1) -Evidence "dexPools=$($restartSummary.dexPools)"
Add-PilotCheck -Name "restart-preserves-bridge-credit-state" -Passed ([int] $restartSummary.bridgeCredits -eq 1) -Evidence "bridgeCredits=$($restartSummary.bridgeCredits)"
Add-PilotCheck -Name "restart-preserves-bridge-receipt-state" -Passed ([int] $restartSummary.bridgeCreditReceipts -eq 1) -Evidence "bridgeCreditReceipts=$($restartSummary.bridgeCreditReceipts)"
Add-PilotCheck -Name "restart-preserves-replay-state" -Passed ([int] $restartSummary.bridgeReplayKeys -eq 1) -Evidence "bridgeReplayKeys=$($restartSummary.bridgeReplayKeys)"

Invoke-FlowChainJsonCargo -Label "Export pilot handoff fixtures" -RuntimeArgs @(
    "--state",
    $statePath,
    "export-fixtures",
    "--out-dir",
    $handoffExportDir
) | Out-Null

$dashboardExport = Get-Content -Raw -LiteralPath (Join-Path $handoffExportDir "dashboard-state.json") | ConvertFrom-Json
$indexerExport = Get-Content -Raw -LiteralPath (Join-Path $handoffExportDir "indexer-handoff.json") | ConvertFrom-Json
$verifierExport = Get-Content -Raw -LiteralPath (Join-Path $handoffExportDir "verifier-handoff.json") | ConvertFrom-Json
$controlPlaneExport = Get-Content -Raw -LiteralPath (Join-Path $handoffExportDir "control-plane-handoff.json") | ConvertFrom-Json
$eventReferenceKey = [string] $receiptByEvent.query.eventReferenceKey
$dashboardCreditProperty = $dashboardExport.bridgeCredits.PSObject.Properties[$pilotCreditId]
$dashboardReceiptProperty = $dashboardExport.bridgeCreditReceipts.PSObject.Properties[$pilotCreditId]
$dashboardEventProperty = $dashboardExport.bridgeEventReceiptIndex.PSObject.Properties[$eventReferenceKey]
$indexerCreditProperty = $indexerExport.bridgeCredits.PSObject.Properties[$pilotCreditId]
$indexerReceiptProperty = $indexerExport.bridgeCreditReceipts.PSObject.Properties[$pilotCreditId]
$indexerEventProperty = $indexerExport.bridgeEventReceiptIndex.PSObject.Properties[$eventReferenceKey]
$verifierCreditProperty = $verifierExport.bridgeCredits.PSObject.Properties[$pilotCreditId]
$verifierReceiptProperty = $verifierExport.bridgeCreditReceipts.PSObject.Properties[$pilotCreditId]
$verifierEventProperty = $verifierExport.bridgeEventReceiptIndex.PSObject.Properties[$eventReferenceKey]
$controlCreditProperty = $controlPlaneExport.objects.bridgeCredits.PSObject.Properties[$pilotCreditId]
$controlReceiptProperty = $controlPlaneExport.objects.bridgeCreditReceipts.PSObject.Properties[$pilotCreditId]
$controlEventProperty = $controlPlaneExport.objects.bridgeEventReceiptIndex.PSObject.Properties[$eventReferenceKey]
$dashboardCreditReceiptId = if ($null -eq $dashboardCreditProperty) { "missing" } else { [string] $dashboardCreditProperty.Value.receiptId }
$dashboardReceiptCreditId = if ($null -eq $dashboardReceiptProperty) { "missing" } else { [string] $dashboardReceiptProperty.Value.bridgeCreditId }
$dashboardEventReceiptId = if ($null -eq $dashboardEventProperty) { "missing" } else { [string] $dashboardEventProperty.Value }
$indexerCreditReceiptId = if ($null -eq $indexerCreditProperty) { "missing" } else { [string] $indexerCreditProperty.Value.receiptId }
$indexerReceiptReplayKey = if ($null -eq $indexerReceiptProperty) { "missing" } else { [string] $indexerReceiptProperty.Value.replayKey }
$indexerEventReceiptId = if ($null -eq $indexerEventProperty) { "missing" } else { [string] $indexerEventProperty.Value }
$verifierCreditReceiptId = if ($null -eq $verifierCreditProperty) { "missing" } else { [string] $verifierCreditProperty.Value.receiptId }
$verifierReceiptReplayKey = if ($null -eq $verifierReceiptProperty) { "missing" } else { [string] $verifierReceiptProperty.Value.replayKey }
$verifierEventReceiptId = if ($null -eq $verifierEventProperty) { "missing" } else { [string] $verifierEventProperty.Value }
$controlCreditAmount = if ($null -eq $controlCreditProperty) { "missing" } else { [string] $controlCreditProperty.Value.amountUnits }
$controlReceiptTxHash = if ($null -eq $controlReceiptProperty) { "missing" } else { [string] $controlReceiptProperty.Value.eventRef.txHash }
$controlEventReceiptId = if ($null -eq $controlEventProperty) { "missing" } else { [string] $controlEventProperty.Value }

Add-PilotCheck -Name "dashboard-export-includes-bridge-credit" -Passed ($dashboardCreditReceiptId -eq $pilotCreditId) -Evidence "dashboard bridge credit receiptId=$dashboardCreditReceiptId"
Add-PilotCheck -Name "dashboard-export-includes-bridge-receipt" -Passed ($dashboardReceiptCreditId -eq $pilotCreditId) -Evidence "dashboard bridge receipt creditId=$dashboardReceiptCreditId"
Add-PilotCheck -Name "dashboard-export-includes-event-index" -Passed ($dashboardEventReceiptId -eq $pilotCreditId) -Evidence "dashboard event key $eventReferenceKey maps to $dashboardEventReceiptId"
Add-PilotCheck -Name "relayer-indexer-export-includes-bridge-credit" -Passed ($indexerCreditReceiptId -eq $pilotCreditId) -Evidence "indexer bridge credit receiptId=$indexerCreditReceiptId"
Add-PilotCheck -Name "relayer-indexer-export-includes-bridge-receipt" -Passed ($indexerReceiptReplayKey -eq $pilotReplayKey) -Evidence "indexer bridge receipt replayKey=$indexerReceiptReplayKey"
Add-PilotCheck -Name "relayer-indexer-export-includes-event-index" -Passed ($indexerEventReceiptId -eq $pilotCreditId) -Evidence "indexer event key $eventReferenceKey maps to $indexerEventReceiptId"
Add-PilotCheck -Name "verifier-export-includes-bridge-credit" -Passed ($verifierCreditReceiptId -eq $pilotCreditId) -Evidence "verifier bridge credit receiptId=$verifierCreditReceiptId"
Add-PilotCheck -Name "verifier-export-includes-bridge-receipt" -Passed ($verifierReceiptReplayKey -eq $pilotReplayKey) -Evidence "verifier bridge receipt replayKey=$verifierReceiptReplayKey"
Add-PilotCheck -Name "verifier-export-includes-event-index" -Passed ($verifierEventReceiptId -eq $pilotCreditId) -Evidence "verifier event key $eventReferenceKey maps to $verifierEventReceiptId"
Add-PilotCheck -Name "control-plane-export-includes-bridge-credit" -Passed ($controlCreditAmount -ne "missing" -and [UInt64] $controlCreditAmount -eq $pilotAmount) -Evidence "control-plane bridge credit amount=$controlCreditAmount"
Add-PilotCheck -Name "control-plane-export-includes-bridge-receipt" -Passed ($controlReceiptTxHash -eq $pilotTxHash) -Evidence "control-plane bridge receipt txHash=$controlReceiptTxHash"
Add-PilotCheck -Name "control-plane-export-includes-event-index" -Passed ($controlEventReceiptId -eq $pilotCreditId) -Evidence "control-plane event key $eventReferenceKey maps to $controlEventReceiptId"
Add-PilotCheck -Name "handoff-exports-preserve-bridge-roots" -Passed ($dashboardExport.mapRoots.bridgeCreditRoot -eq $restartSummary.mapRoots.bridgeCreditRoot -and $indexerExport.mapRoots.bridgeReplayIndexRoot -eq $restartSummary.mapRoots.bridgeReplayIndexRoot -and $verifierExport.mapRoots.bridgeEventReceiptIndexRoot -eq $restartSummary.mapRoots.bridgeEventReceiptIndexRoot -and $controlPlaneExport.mapRoots.bridgeCreditReceiptRoot -eq $restartSummary.mapRoots.bridgeCreditReceiptRoot) -Evidence "dashboard bridgeCreditRoot=$($dashboardExport.mapRoots.bridgeCreditRoot), indexer bridgeReplayIndexRoot=$($indexerExport.mapRoots.bridgeReplayIndexRoot), verifier bridgeEventReceiptIndexRoot=$($verifierExport.mapRoots.bridgeEventReceiptIndexRoot), control bridgeCreditReceiptRoot=$($controlPlaneExport.mapRoots.bridgeCreditReceiptRoot)"

$exported = Invoke-FlowChainJsonCargo -Label "Export pilot state" -RuntimeArgs @(
    "--state",
    $statePath,
    "export-state",
    "--out",
    $snapshotPath
)
Invoke-FlowChainJsonCargo -Label "Import pilot state" -RuntimeArgs @(
    "--state",
    $importedStatePath,
    "import-state",
    "--from",
    $snapshotPath
) | Out-Null
$imported = Invoke-FlowChainJsonCargo -Label "Inspect imported state" -RuntimeArgs @(
    "--state",
    $importedStatePath,
    "inspect-state",
    "--summary"
)

Add-PilotCheck -Name "export-import-preserves-state-root" -Passed ($exported.stateRoot -eq $imported.stateRoot -and $restartSummary.stateRoot -eq $imported.stateRoot) -Evidence "before=$($restartSummary.stateRoot), exported=$($exported.stateRoot), imported=$($imported.stateRoot)"
Add-PilotCheck -Name "export-import-preserves-bridge-asset-mapping-root" -Passed ($restartSummary.mapRoots.bridgeAssetMappingRoot -eq $imported.mapRoots.bridgeAssetMappingRoot) -Evidence "before=$($restartSummary.mapRoots.bridgeAssetMappingRoot), imported=$($imported.mapRoots.bridgeAssetMappingRoot)"
Add-PilotCheck -Name "export-import-preserves-bridge-account-mapping-root" -Passed ($restartSummary.mapRoots.bridgeAccountMappingRoot -eq $imported.mapRoots.bridgeAccountMappingRoot) -Evidence "before=$($restartSummary.mapRoots.bridgeAccountMappingRoot), imported=$($imported.mapRoots.bridgeAccountMappingRoot)"
Add-PilotCheck -Name "export-import-preserves-bridge-credit-root" -Passed ($restartSummary.mapRoots.bridgeCreditRoot -eq $imported.mapRoots.bridgeCreditRoot) -Evidence "before=$($restartSummary.mapRoots.bridgeCreditRoot), imported=$($imported.mapRoots.bridgeCreditRoot)"
Add-PilotCheck -Name "export-import-preserves-bridge-receipt-root" -Passed ($restartSummary.mapRoots.bridgeCreditReceiptRoot -eq $imported.mapRoots.bridgeCreditReceiptRoot) -Evidence "before=$($restartSummary.mapRoots.bridgeCreditReceiptRoot), imported=$($imported.mapRoots.bridgeCreditReceiptRoot)"
Add-PilotCheck -Name "export-import-preserves-bridge-replay-index-root" -Passed ($restartSummary.mapRoots.bridgeReplayIndexRoot -eq $imported.mapRoots.bridgeReplayIndexRoot) -Evidence "before=$($restartSummary.mapRoots.bridgeReplayIndexRoot), imported=$($imported.mapRoots.bridgeReplayIndexRoot)"
Add-PilotCheck -Name "export-import-preserves-bridge-event-receipt-index-root" -Passed ($restartSummary.mapRoots.bridgeEventReceiptIndexRoot -eq $imported.mapRoots.bridgeEventReceiptIndexRoot) -Evidence "before=$($restartSummary.mapRoots.bridgeEventReceiptIndexRoot), imported=$($imported.mapRoots.bridgeEventReceiptIndexRoot)"

$reportPath = Join-Path $runFullDir "flowchain-real-value-pilot-e2e-report.json"
$report = [ordered]@{
    schema = "flowchain.real_value_pilot.runtime_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    commit = (& git rev-parse HEAD).Trim()
    status = $(if ($missing.Count -eq 0) { "passed" } else { "incomplete" })
    handoffPath = $handoffFullPath
    handoffSource = $handoffSource
    statePath = $statePath
    handoffExportDir = $handoffExportDir
    snapshotPath = $snapshotPath
    importedStatePath = $importedStatePath
    credit = [ordered]@{
        creditId = $pilotCreditId
        replayKey = $pilotReplayKey
        creditTransactionId = $creditTxId
        duplicateCreditTransactionId = $duplicateCreditTxId
        receiptId = $pilotCreditId
        localBridgeAccountId = $expectedBridgeAccountId
        amount = $pilotAmount
        source = [ordered]@{
            chainId = $pilotSourceChainId
            contract = $pilotSourceContract
            txHash = $pilotTxHash
            logIndex = $pilotLogIndex
        }
    }
    roots = [ordered]@{
        stateRoot = $imported.stateRoot
        bridgeAssetMappingRoot = $imported.mapRoots.bridgeAssetMappingRoot
        bridgeAccountMappingRoot = $imported.mapRoots.bridgeAccountMappingRoot
        bridgeCreditRoot = $imported.mapRoots.bridgeCreditRoot
        bridgeCreditReceiptRoot = $imported.mapRoots.bridgeCreditReceiptRoot
        bridgeReplayIndexRoot = $imported.mapRoots.bridgeReplayIndexRoot
        bridgeEventReceiptIndexRoot = $imported.mapRoots.bridgeEventReceiptIndexRoot
    }
    receiptById = $receiptById
    receiptByEvent = $receiptByEvent
    checks = $checks
    missingCoverage = @($missing)
}

Write-FlowChainJson -Path $reportPath -Value $report -Depth 18
Assert-FlowChainNoSecretFiles -Path $runFullDir

Write-Host ""
Write-Host "FlowChain real-value pilot runtime E2E report: $reportPath"
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "FlowChain real-value pilot runtime E2E is incomplete:"
    foreach ($item in $missing) {
        Write-Host "- $item"
    }
    throw "FlowChain real-value pilot runtime E2E is incomplete."
}

Write-Host "FlowChain real-value pilot runtime E2E passed."
