param(
    [string] $OutDir = "devnet/local/network-e2e",
    [string] $ReportName = "network-e2e-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Invoke-FlowChainDevnetJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $ArgumentList,

        [Parameter(Mandatory = $true)]
        [string] $Label
    )

    Write-Host ""
    Write-Host "== $Label =="
    $output = & cargo @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }

    return (($output | Out-String) | ConvertFrom-Json)
}

function Start-FlowChainNodeAndWait {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $ArgumentList,

        [Parameter(Mandatory = $true)]
        [string] $StdoutPath,

        [Parameter(Mandatory = $true)]
        [string] $StderrPath,

        [Parameter(Mandatory = $true)]
        [string] $Label,

        [int] $TimeoutMs = 45000
    )

    Write-Host ""
    Write-Host "== $Label =="
    $process = Start-Process -FilePath "cargo" -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) -WorkingDirectory $script:RepoRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    if (-not $process.WaitForExit($TimeoutMs)) {
        $process.Kill()
        throw "$Label did not stop after bounded run."
    }
    $process.Refresh()
    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
        $stderr = ""
        if (Test-Path -LiteralPath $StderrPath) {
            $stderr = Get-Content -Raw -LiteralPath $StderrPath
        }
        throw "$Label failed with exit code $($process.ExitCode). $stderr"
    }
}

function New-FlowChainPeer {
    param(
        [Parameter(Mandatory = $true)]
        [string] $NodeId,

        [Parameter(Mandatory = $true)]
        [string] $Role,

        [Parameter(Mandatory = $true)]
        [string] $StatePath,

        [string] $NodeDir = "",
        [string] $ChainId = $script:ChainId,
        [string] $GenesisHash = $script:GenesisHash,
        [string] $ProtocolVersion = "flowchain-local-network/0.1.0"
    )

    $safeNodeId = $NodeId -replace '[^A-Za-z0-9_.-]', '-'
    $peer = [ordered]@{
        nodeId = $NodeId
        role = $Role
        address = "flowchain-local://$safeNodeId@$StatePath"
        peerAddress = "flowchain-local://$safeNodeId@$StatePath"
        listenAddress = "flowchain-local://$safeNodeId@$StatePath"
        bindAddress = "local-file://$StatePath#$safeNodeId"
        statePath = $StatePath
        chainId = $ChainId
        genesisHash = $GenesisHash
        protocolVersion = $ProtocolVersion
    }

    if (-not [string]::IsNullOrWhiteSpace($NodeDir)) {
        $peer["nodeDir"] = $NodeDir
        $peer["dataDir"] = $NodeDir
        $peer["listenAddress"] = "flowchain-local://$safeNodeId@$NodeDir"
        $peer["peerAddress"] = $peer["listenAddress"]
        $peer["address"] = $peer["listenAddress"]
        $peer["bindAddress"] = "local-file://$NodeDir#$safeNodeId"
    }

    return $peer
}

function Write-FlowChainPeerConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $NodeId,

        [Parameter(Mandatory = $true)]
        [string] $Role,

        [Parameter(Mandatory = $true)]
        [string] $StatePath,

        [Parameter(Mandatory = $true)]
        [string] $NodeDir,

        [object[]] $Peers = @()
    )

    $safeNodeId = $NodeId -replace '[^A-Za-z0-9_.-]', '-'
    Write-FlowChainJson -Path $Path -Depth 16 -Value ([ordered]@{
        schema = "flowmemory.local_devnet.peer_config.v1"
        nodeId = $NodeId
        networkProfile = "local-file-private-testnet"
        chainId = $script:ChainId
        genesisHash = $script:GenesisHash
        protocolVersion = "flowchain-local-network/0.1.0"
        role = $Role
        listenAddress = "flowchain-local://$safeNodeId@$NodeDir"
        bindAddress = "local-file://$NodeDir#$safeNodeId"
        dataDir = $NodeDir
        statePath = $StatePath
        staticPeers = $Peers
    })
}

function Get-FlowChainPeerStatus {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Status,

        [Parameter(Mandatory = $true)]
        [string] $PeerId
    )

    return @($Status.persistedStatus.peers) | Where-Object { $_.peerId -eq $PeerId } | Select-Object -First 1
}

function Count-FlowChainTxReceipt {
    param(
        [Parameter(Mandatory = $true)]
        [object] $State,

        [Parameter(Mandatory = $true)]
        [string] $TxId
    )

    $count = 0
    foreach ($block in @($State.blocks)) {
        foreach ($receipt in @($block.receipts)) {
            if ($receipt.txId -eq $TxId) {
                $count += 1
            }
        }
    }
    return $count
}

$script:RepoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $script:RepoRoot -Purpose "network-e2e" | Out-Null
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $script:RepoRoot -Path (Resolve-FlowChainPath -RepoRoot $script:RepoRoot -Path $OutDir)

if (Test-Path -LiteralPath $outFullDir) {
    Remove-Item -LiteralPath $outFullDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

$stateA = Join-Path $outFullDir "node-a-state.json"
$stateB = Join-Path $outFullDir "node-b-state.json"
$stateStale = Join-Path $outFullDir "node-stale-state.json"
$stateWrongChain = Join-Path $outFullDir "node-wrong-chain-state.json"
$stateWrongGenesis = Join-Path $outFullDir "node-wrong-genesis-state.json"
$stateUnsupported = Join-Path $outFullDir "node-unsupported-protocol-state.json"
$stateInvalidParent = Join-Path $outFullDir "node-invalid-parent-state.json"

$nodeA = Join-Path $outFullDir "node-a"
$nodeB = Join-Path $outFullDir "node-b"
$nodeStale = Join-Path $outFullDir "node-stale"
$nodeWrongChain = Join-Path $outFullDir "node-wrong-chain"
$nodeWrongGenesis = Join-Path $outFullDir "node-wrong-genesis"
$nodeUnsupported = Join-Path $outFullDir "node-unsupported-protocol"
$nodeInvalidParent = Join-Path $outFullDir "node-invalid-parent"

$peerA = Join-Path $outFullDir "node-a-peers.json"
$peerB = Join-Path $outFullDir "node-b-peers.json"

$cargoBase = @("run", "--manifest-path", "crates/flowmemory-devnet/Cargo.toml", "--")

foreach ($statePath in @($stateA, $stateB, $stateStale, $stateWrongChain, $stateWrongGenesis, $stateUnsupported)) {
    Invoke-FlowChainDevnetJson -Label "Initialize $statePath" -ArgumentList ($cargoBase + @("--state", $statePath, "init")) | Out-Null
}

$genesisState = Get-Content -Raw -LiteralPath $stateA | ConvertFrom-Json
$script:ChainId = $genesisState.chainId
$script:GenesisHash = $genesisState.genesisHash
$wrongGenesisHash = "0x" + ("1" * 64)

$wrongChain = Get-Content -Raw -LiteralPath $stateWrongChain | ConvertFrom-Json
$wrongChain.chainId = "flowmemory-wrong-chain-v0"
$wrongChain.config.chainId = "flowmemory-wrong-chain-v0"
Write-FlowChainJson -Path $stateWrongChain -Depth 16 -Value $wrongChain

$wrongGenesis = Get-Content -Raw -LiteralPath $stateWrongGenesis | ConvertFrom-Json
$wrongGenesis.genesisHash = $wrongGenesisHash
$wrongGenesis.config.genesisHash = $wrongGenesisHash
$wrongGenesis.parentHash = $wrongGenesisHash
Write-FlowChainJson -Path $stateWrongGenesis -Depth 16 -Value $wrongGenesis

$peersForA = @(
    (New-FlowChainPeer -NodeId "node:network:b" -Role "full-node" -StatePath $stateB -NodeDir $nodeB),
    (New-FlowChainPeer -NodeId "node:network:stale" -Role "full-node" -StatePath $stateStale -NodeDir $nodeStale),
    (New-FlowChainPeer -NodeId "node:network:wrong-chain" -Role "full-node" -StatePath $stateWrongChain -NodeDir $nodeWrongChain -ChainId "flowmemory-wrong-chain-v0"),
    (New-FlowChainPeer -NodeId "node:network:wrong-genesis" -Role "full-node" -StatePath $stateWrongGenesis -NodeDir $nodeWrongGenesis -GenesisHash $wrongGenesisHash),
    (New-FlowChainPeer -NodeId "node:network:unsupported" -Role "full-node" -StatePath $stateUnsupported -NodeDir $nodeUnsupported -ProtocolVersion "flowchain-local-network/9.9.9"),
    (New-FlowChainPeer -NodeId "node:network:invalid-parent" -Role "full-node" -StatePath $stateInvalidParent -NodeDir $nodeInvalidParent)
)
$peersForB = @(
    (New-FlowChainPeer -NodeId "node:network:a" -Role "block-producer" -StatePath $stateA -NodeDir $nodeA)
)

Write-FlowChainPeerConfig -Path $peerA -NodeId "node:network:a" -Role "block-producer" -StatePath $stateA -NodeDir $nodeA -Peers $peersForA
Write-FlowChainPeerConfig -Path $peerB -NodeId "node:network:b" -Role "full-node" -StatePath $stateB -NodeDir $nodeB -Peers $peersForB

$queued = Invoke-FlowChainDevnetJson -Label "Submit signed local transaction to node A" -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "faucet",
    "--account", "local-account:network-e2e",
    "--amount", "77",
    "--reason", "network-e2e",
    "--authorized-by", "local-network-operator"
))

Start-FlowChainNodeAndWait -Label "Run node A as block producer" -StdoutPath (Join-Path $outFullDir "node-a.first.stdout.jsonl") -StderrPath (Join-Path $outFullDir "node-a.first.stderr.log") -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "node",
    "--node-id", "node:network:a",
    "--block-ms", "50",
    "--max-blocks", "4",
    "--peer-config", $peerA
))

$invalidParent = Get-Content -Raw -LiteralPath $stateA | ConvertFrom-Json
if (@($invalidParent.blocks).Count -lt 1) {
    throw "Cannot build invalid-parent fixture before node A has blocks."
}
$invalidParent.blocks[0].parentHash = "0x" + ("2" * 64)
Write-FlowChainJson -Path $stateInvalidParent -Depth 16 -Value $invalidParent

Start-FlowChainNodeAndWait -Label "Run node B and reconcile from node A" -StdoutPath (Join-Path $outFullDir "node-b.first.stdout.jsonl") -StderrPath (Join-Path $outFullDir "node-b.first.stderr.log") -ArgumentList ($cargoBase + @(
    "--state", $stateB,
    "--node-dir", $nodeB,
    "node",
    "--node-id", "node:network:b",
    "--block-ms", "50",
    "--max-blocks", "1",
    "--peer-config", $peerB
))

Invoke-FlowChainDevnetJson -Label "Reconcile node A from node B after node B block" -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "sync",
    "--node-id", "node:network:a",
    "--peer-config", $peerA
)) | Out-Null

$statusABeforeRestart = Invoke-FlowChainDevnetJson -Label "Read node A status before restart phase" -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "node-status"
))
$statusBBeforeRestart = Invoke-FlowChainDevnetJson -Label "Read node B status before restart phase" -ArgumentList ($cargoBase + @(
    "--state", $stateB,
    "--node-dir", $nodeB,
    "node-status"
))

Invoke-FlowChainDevnetJson -Label "Stop node B" -ArgumentList ($cargoBase + @(
    "--state", $stateB,
    "--node-dir", $nodeB,
    "node-stop"
)) | Out-Null

Start-FlowChainNodeAndWait -Label "Advance node A while node B is stopped" -StdoutPath (Join-Path $outFullDir "node-a.restart.stdout.jsonl") -StderrPath (Join-Path $outFullDir "node-a.restart.stderr.log") -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "node",
    "--node-id", "node:network:a",
    "--block-ms", "50",
    "--max-blocks", "3",
    "--peer-config", $peerA
))

$statusAAdvanced = Invoke-FlowChainDevnetJson -Label "Read advanced node A status" -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "node-status"
))

Start-FlowChainNodeAndWait -Label "Restart node B and catch up from node A" -StdoutPath (Join-Path $outFullDir "node-b.restart.stdout.jsonl") -StderrPath (Join-Path $outFullDir "node-b.restart.stderr.log") -ArgumentList ($cargoBase + @(
    "--state", $stateB,
    "--node-dir", $nodeB,
    "node",
    "--node-id", "node:network:b",
    "--block-ms", "50",
    "--max-blocks", "1",
    "--peer-config", $peerB
))

Invoke-FlowChainDevnetJson -Label "Final reconcile node A from restarted node B" -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "sync",
    "--node-id", "node:network:a",
    "--peer-config", $peerA
)) | Out-Null

$summaryA = Invoke-FlowChainDevnetJson -Label "Final node A status" -ArgumentList ($cargoBase + @(
    "--state", $stateA,
    "--node-dir", $nodeA,
    "node-status"
))
$summaryB = Invoke-FlowChainDevnetJson -Label "Final node B status" -ArgumentList ($cargoBase + @(
    "--state", $stateB,
    "--node-dir", $nodeB,
    "node-status"
))

if ($summaryA.state.blocks -ne $summaryB.state.blocks) {
    throw "Nodes did not end at the same height. A=$($summaryA.state.blocks) B=$($summaryB.state.blocks)"
}
if ($summaryA.state.stateRoot -ne $summaryB.state.stateRoot) {
    throw "Nodes did not end at the same state root. A=$($summaryA.state.stateRoot) B=$($summaryB.state.stateRoot)"
}
if ($summaryB.state.localBalances -lt 1 -or $summaryB.state.faucetRecords -lt 1) {
    throw "Node B cannot query the transaction state after sync."
}

$wrongChainPeer = Get-FlowChainPeerStatus -Status $summaryA -PeerId "node:network:wrong-chain"
$wrongGenesisPeer = Get-FlowChainPeerStatus -Status $summaryA -PeerId "node:network:wrong-genesis"
$unsupportedPeer = Get-FlowChainPeerStatus -Status $summaryA -PeerId "node:network:unsupported"
$stalePeer = Get-FlowChainPeerStatus -Status $summaryA -PeerId "node:network:stale"
$invalidParentPeer = Get-FlowChainPeerStatus -Status $summaryA -PeerId "node:network:invalid-parent"

if ($wrongChainPeer.status -ne "wrongChain") {
    throw "Wrong-chain peer was not rejected."
}
if ($wrongGenesisPeer.status -ne "wrongGenesis") {
    throw "Wrong-genesis peer was not rejected."
}
if ($unsupportedPeer.status -ne "unsupportedProtocol") {
    throw "Unsupported protocol peer was not rejected."
}
if ($stalePeer.syncStatus -ne "stalePeer") {
    throw "Stale peer head was not reported as stale."
}
if ($invalidParentPeer.syncStatus -ne "syncBlocked" -or $invalidParentPeer.rejectedBlock.reason -ne "invalidParentBlock") {
    throw "Invalid parent block was not rejected."
}

$stateAJson = Get-Content -Raw -LiteralPath $stateA | ConvertFrom-Json
$stateBJson = Get-Content -Raw -LiteralPath $stateB | ConvertFrom-Json
$duplicateEvidence = @()
foreach ($txId in @($queued.queued)) {
    $duplicateEvidence += [ordered]@{
        txId = $txId
        nodeAReceiptCount = Count-FlowChainTxReceipt -State $stateAJson -TxId $txId
        nodeBReceiptCount = Count-FlowChainTxReceipt -State $stateBJson -TxId $txId
    }
}
foreach ($evidence in $duplicateEvidence) {
    if ($evidence.nodeAReceiptCount -ne 1 -or $evidence.nodeBReceiptCount -ne 1) {
        throw "Duplicate transaction evidence failed for $($evidence.txId)."
    }
}

$reportPath = Join-Path $outFullDir $ReportName
$report = [ordered]@{
    schema = "flowchain.private_testnet.network_e2e.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    reportPath = $reportPath
    networkProfile = "local-file-private-testnet"
    protocolVersion = "flowchain-local-network/0.1.0"
    chainId = $script:ChainId
    genesisHash = $script:GenesisHash
    nodeIds = @("node:network:a", "node:network:b")
    peerConfigFiles = @($peerA, $peerB)
    nodes = [ordered]@{
        nodeA = [ordered]@{
            nodeId = "node:network:a"
            statePath = $stateA
            nodeDir = $nodeA
            height = $summaryA.state.blocks
            latestHash = $summaryA.state.parentHash
            stateRoot = $summaryA.state.stateRoot
            peerStatus = $summaryA.persistedStatus.peers
            syncStatus = $summaryA.persistedStatus.syncStatus
        }
        nodeB = [ordered]@{
            nodeId = "node:network:b"
            statePath = $stateB
            nodeDir = $nodeB
            height = $summaryB.state.blocks
            latestHash = $summaryB.state.parentHash
            stateRoot = $summaryB.state.stateRoot
            peerStatus = $summaryB.persistedStatus.peers
            syncStatus = $summaryB.persistedStatus.syncStatus
        }
    }
    sharedStateRootEvidence = [ordered]@{
        sameHeight = ($summaryA.state.blocks -eq $summaryB.state.blocks)
        sameStateRoot = ($summaryA.state.stateRoot -eq $summaryB.state.stateRoot)
        height = $summaryA.state.blocks
        stateRoot = $summaryA.state.stateRoot
    }
    txPropagationEvidence = [ordered]@{
        submittedTo = "node:network:a"
        queryNode = "node:network:b"
        queuedTxIds = $queued.queued
        localBalanceQueryableOnNodeB = ($summaryB.state.localBalances -ge 1)
        faucetRecordQueryableOnNodeB = ($summaryB.state.faucetRecords -ge 1)
        duplicateReceiptEvidence = $duplicateEvidence
    }
    rejectedPeerEvidence = [ordered]@{
        wrongChain = $wrongChainPeer
        wrongGenesis = $wrongGenesisPeer
        unsupportedProtocol = $unsupportedPeer
        staleBlock = $stalePeer
        invalidParentBlock = $invalidParentPeer
    }
    restartEvidence = [ordered]@{
        stoppedNodeId = "node:network:b"
        beforeRestartHeightA = $statusABeforeRestart.state.blocks
        beforeRestartHeightB = $statusBBeforeRestart.state.blocks
        producerAdvancedHeight = $statusAAdvanced.state.blocks
        afterRestartHeightA = $summaryA.state.blocks
        afterRestartHeightB = $summaryB.state.blocks
        caughtUp = ($summaryA.state.blocks -eq $summaryB.state.blocks -and $summaryA.state.stateRoot -eq $summaryB.state.stateRoot)
    }
    bridgeBoundary = [ordered]@{
        baseObservationMode = "operator-or-relayer-function"
        localBridgeCreditPropagation = "authorized local transactions only when represented in this private L1"
        duplicateBridgeCreditBoundary = "duplicate transaction ids are not included twice"
    }
}
Write-FlowChainJson -Path $reportPath -Depth 24 -Value $report

Write-Host ""
Write-Host "FlowChain private/local network E2E passed."
Write-Host "Height: $($summaryA.state.blocks)"
Write-Host "State root: $($summaryA.state.stateRoot)"
Write-Host "Report: $reportPath"
