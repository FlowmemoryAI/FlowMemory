# Handshake Proof

## Exchanged Fields

The deterministic private handshake checks:

- `nodeId`
- `chainId`
- `genesisHash`
- `protocolVersion`
- latest height
- latest hash
- state root
- role and local address metadata

## Rejection Rules

- Wrong `chainId` becomes peer `status: wrongChain`.
- Wrong `genesisHash` becomes peer `status: wrongGenesis`.
- Unsupported `protocolVersion` becomes peer `status: unsupportedProtocol`.
- Missing peer state becomes `connectionStatus: disconnected`.

## Evidence

`npm run flowchain:network:e2e` writes rejected peer evidence for wrong chain, wrong genesis, unsupported protocol, stale peer, and invalid parent block under:

```text
devnet/local/network-e2e/network-e2e-report.json
```

The same proof is run by `npm run flowchain:multi-node:smoke` and written under:

```text
devnet/local/multi-node-smoke/multi-node-smoke-report.json
```
