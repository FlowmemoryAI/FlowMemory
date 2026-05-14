# Production L1 Networking Handoff

## What Changed

- Added `flowmemory.local_devnet.peer_config.v1` with node ID, listen/bind addresses, peer address, chain ID, genesis hash, protocol version, role, data directory, state path, and static peers.
- Added deterministic handshake/status handling for connected, disconnected, wrong chain, wrong genesis, unsupported protocol, syncing, caught up, stale peer, and sync-blocked peers.
- Added validated deterministic peer sync and transaction relay markers inside the Rust devnet runtime.
- Added `sync` / `sync-once` CLI command for reconciliation without producing a block.
- Added `infra/scripts/flowchain-network-e2e.ps1` and `npm run flowchain:network:e2e`.
- Updated `npm run flowchain:multi-node:smoke` to run the strict network proof.

## Peer Config Shape

Required node fields:

- `schema`
- `nodeId`
- `networkProfile`
- `chainId`
- `genesisHash`
- `protocolVersion`
- `role`
- `listenAddress`
- `bindAddress`
- `dataDir`
- `statePath`
- `staticPeers[]`

Required peer fields:

- `nodeId`
- `role`
- `peerAddress` or `listenAddress`
- `bindAddress`
- `nodeDir`
- `statePath`
- `chainId`
- `genesisHash`
- `protocolVersion`

## Status Fields

RPC/dashboard can read `node-status` or node `status.json` for:

- node: `nodeId`, `networkProfile`, `chainId`, `genesisHash`, `protocolVersion`, `role`, `listenAddress`, `bindAddress`
- chain: `blockHeight`, `finalizedHeight`, `nextBlockNumber`, `latestBlockHash`, `stateRoot`
- sync: `syncStatus`, `staticPeerSync`, `peers[]`, `rejectedBlocks[]`
- peer: `peerId`, `connectionStatus`, `status`, `syncStatus`, `latestHeight`, `latestHash`, `lastSeenHeight`, `lastSeenHash`, `remoteStateRoot`, `reconnectAttempts`, `rejectedBlock`

## Report Paths

- `devnet/local/network-e2e/network-e2e-report.json`
- `devnet/local/multi-node-smoke/multi-node-smoke-report.json`

## RPC/Dashboard Boundary

Dashboards should display network status from `node-status` or `status.json`, not from process logs. Logs include node IDs, block hashes, tx counts, state roots, sync status, and peer state only. No secrets, private keys, seed phrases, RPC credentials, or webhook URLs are written by this networking layer.

## Bridge Boundary

Base observation remains an operator or relayer function. Bridge credits represented inside this local/private L1 must enter as normal locally authorized transactions. Duplicate transaction IDs are not included twice, so duplicate local bridge-credit propagation does not double credit.
