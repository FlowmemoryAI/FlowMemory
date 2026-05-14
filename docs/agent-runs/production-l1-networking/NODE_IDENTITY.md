# Node Identity Proof

## Identity Shape

Each private/local FlowChain node is identified by:

- `nodeId`: stable operator-selected ID, for example `node:network:a`.
- `networkProfile`: `local-file-private-testnet`.
- `chainId`: `flowmemory-local-devnet-v0`.
- `genesisHash`: `0x0f23c892cbd2d00c10839d97ddab833698a83f8df8d6df27ceac03cfdd4b7bc9`.
- `protocolVersion`: `flowchain-local-network/0.1.0`.
- `role`: currently `block-producer` or `full-node`.
- `listenAddress`: public local address string, for example `flowchain-local://node-network-a@devnet/local/network-e2e/node-a`.
- `bindAddress`: private local bind string, for example `local-file://devnet/local/network-e2e/node-a#node-network-a`.
- `dataDir`, `statePath`, and `staticPeers`.

## Runtime Files

The runtime writes `node-identity.json` and `status.json` inside each node directory. These files contain no signing secrets. The safe API/dashboard metadata is a subset of node ID, network profile, chain/genesis, protocol version, role, and listen address.

## Evidence

- Command: `npm run flowchain:network:e2e`
- Report: `devnet/local/network-e2e/network-e2e-report.json`
- Smoke report: `devnet/local/multi-node-smoke/multi-node-smoke-report.json`
