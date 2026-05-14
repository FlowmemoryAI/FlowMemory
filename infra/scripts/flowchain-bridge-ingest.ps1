param(
    [Parameter(Mandatory = $true)]
    [string] $HandoffPath,

    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $OutDir = "devnet/local/live-l1-bridge-intake",
    [int] $TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-ObjectPropertyCount {
    param([object] $Value)
    if ($null -eq $Value -or $null -eq $Value.PSObject) {
        return 0
    }
    return @($Value.PSObject.Properties).Count
}

function Get-FirstPropertyValue {
    param([object] $Value)
    $properties = @($Value.PSObject.Properties)
    if ($properties.Count -lt 1) {
        return $null
    }
    return $properties[0].Value
}

function Convert-FlowChainTimestampSeconds {
    param([Parameter(Mandatory = $true)][object] $Value)

    $text = [string] $Value
    $numeric = 0.0
    if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $numeric)) {
        return $numeric
    }

    return ([DateTimeOffset]::Parse($text, [System.Globalization.CultureInfo]::InvariantCulture)).ToUnixTimeSeconds()
}

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "bridge-ingest" | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$handoffFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $HandoffPath)
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

if (-not (Test-Path -LiteralPath $handoffFullPath)) {
    throw "Bridge handoff file does not exist: $handoffFullPath"
}

$statusPath = Join-Path $nodeFullDir "status.json"
if (-not (Test-Path -LiteralPath $statusPath)) {
    throw "Node status is missing. Start the node with npm run flowchain:node:start first."
}
$status = Read-JsonFile -Path $statusPath
if ($status.status -ne "running") {
    throw "Node is not running; status is '$($status.status)'."
}

$beforeState = if (Test-Path -LiteralPath $stateFullPath) { Read-JsonFile -Path $stateFullPath } else { $null }
$beforeCredits = if ($null -eq $beforeState) { 0 } else { Get-ObjectPropertyCount -Value $beforeState.bridgeCredits }

$handoff = Read-JsonFile -Path $handoffFullPath
if ($handoff.schema -ne "flowmemory.bridge_runtime_handoff.v0") {
    throw "Unsupported bridge handoff schema: $($handoff.schema)"
}
if ($handoff.productionReady -ne $true -or $handoff.localOnly -ne $false) {
    throw "Live intake requires productionReady=true and localOnly=false handoff flags."
}

$ingestOutput = (& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath --node-dir $nodeFullDir bridge-ingest --handoff $handoffFullPath --authorized-by operator:bridge:live-pilot --require-live 2>&1) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    throw "Bridge ingest command failed.`n$ingestOutput"
}
$jsonStart = $ingestOutput.IndexOf("{")
$jsonEnd = $ingestOutput.LastIndexOf("}")
if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
    throw "Bridge ingest command did not emit JSON.`n$ingestOutput"
}
$ingest = $ingestOutput.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
if (@($ingest.queued.queued).Count -lt 1) {
    throw "Bridge ingest did not queue any runtime transactions."
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$afterState = $null
$firstCredit = $null
$receipt = $null
while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $stateFullPath) {
        try {
            $candidate = Read-JsonFile -Path $stateFullPath
            if ((Get-ObjectPropertyCount -Value $candidate.bridgeCredits) -gt $beforeCredits) {
                $afterState = $candidate
                $firstCredit = Get-FirstPropertyValue -Value $candidate.bridgeCredits
                if ($null -ne $firstCredit) {
                    $receiptProp = $candidate.bridgeCreditReceipts.PSObject.Properties[$firstCredit.creditId]
                    if ($null -ne $receiptProp) {
                        $receipt = $receiptProp.Value
                        break
                    }
                }
            }
        }
        catch {
        }
    }
    Start-Sleep -Milliseconds 500
}

if ($null -eq $afterState -or $null -eq $firstCredit -or $null -eq $receipt) {
    throw "Timed out waiting for bridge credit application in $stateFullPath."
}

$latencyTotalSeconds = $receipt.latency.totalSeconds
if ($null -eq $latencyTotalSeconds) {
    $latencyTotalSeconds = [int] ((Convert-FlowChainTimestampSeconds -Value $receipt.latency.firstSpendableAt) - (Convert-FlowChainTimestampSeconds -Value $receipt.latency.handoffWrittenAt))
}
if ([int] $latencyTotalSeconds -gt 60) {
    throw "Bridge intake exceeded 60 seconds after handoff: $latencyTotalSeconds."
}

$balance = $afterState.localTestUnitBalances.PSObject.Properties[$firstCredit.recipientAccountId].Value
if ($null -eq $balance -or [UInt64] $balance.units -lt [UInt64] $firstCredit.amountUnits) {
    throw "Credited balance is missing or lower than credit amount."
}

$report = [ordered]@{
    schema = "flowchain.live_l1.bridge_ingest_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    handoffPath = $handoffFullPath
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    nodeStatus = $status
    queued = $ingest.queued
    bridgeCreditsBefore = $beforeCredits
    bridgeCreditsAfter = Get-ObjectPropertyCount -Value $afterState.bridgeCredits
    bridgeCreditReceipts = Get-ObjectPropertyCount -Value $afterState.bridgeCreditReceipts
    bridgeReplayKeys = Get-ObjectPropertyCount -Value $afterState.bridgeReplayKeys
    creditedAccount = $firstCredit.recipientAccountId
    creditedBalance = $balance.units
    creditId = $firstCredit.creditId
    receiptId = $receipt.receiptId
    latency = [ordered]@{
        baseObservedAt = $receipt.latency.baseObservedAt
        handoffWrittenAt = $receipt.latency.handoffWrittenAt
        nodeIngestedAt = $receipt.latency.nodeIngestedAt
        creditAppliedAt = $receipt.latency.creditAppliedAt
        firstSpendableAt = $receipt.latency.firstSpendableAt
        totalSeconds = [int] $latencyTotalSeconds
    }
    passed = $true
}

$reportPath = Join-Path $outFullDir "bridge-ingest-report.json"
Write-FlowChainJson -Path $reportPath -Value $report -Depth 24
$report | ConvertTo-Json -Depth 24
