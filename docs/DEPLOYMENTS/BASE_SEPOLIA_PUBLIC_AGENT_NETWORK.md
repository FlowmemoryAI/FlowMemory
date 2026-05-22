# Base Sepolia Public Agent Network Rehearsal

Status: operator runbook and non-secret plan for issue #164.

This is a Base Sepolia public testnet rehearsal path. It is not production, not mainnet readiness, not an audit result, and not approval for uncapped value-bearing use.

## Configured Deployer

The current public testnet deployer address is:

```text
0x69F55917209C446bf9d31D2903e01966B75a8cDe
```

Explorer:

```text
https://sepolia.basescan.org/address/0x69F55917209C446bf9d31D2903e01966B75a8cDe
```

Only the public address belongs in Git. Never include private keys, RPC URLs, explorer API keys, `.env` content, seed phrases, or wallet secrets in docs, GitHub issues, PR comments, screenshots, or committed artifacts.

## What The Rehearsal Deploys

`script/DeployPublicAgentNetworkBaseSepolia.s.sol` deploys and smoke-exercises:

- `BaseOnchainAgentMemory`
- `AgentClassRegistry`
- `ToolRegistry`
- `AgentProfileRegistry`
- `AgentLaunchBondEscrow`
- `AgentMemoryFuelVault`
- `AgentLineageRegistry`
- `AgentReceiptAnchor`
- `AgentShellFactory`
- `AgentFactory`
- `SwarmPolicyRegistry`
- `SwarmRegistry`
- `SwarmBudgetVault`
- `SwarmFactory`
- `PublicNetworkBaseSepoliaToken` test token

The script then emits public-safe evidence for class/tool registration, launch bond policy, memory fuel policy, one deployer-owned task-scout agent launch, one receipt anchor, one research swarm, and the swarm budget deposit/line/reserve/release/spend path.

## Plan-Only Command

This writes the committed non-secret plan artifact and does not require a private key:

```powershell
npm run public-agent-network:base-sepolia:plan -- --deployer-address 0x69F55917209C446bf9d31D2903e01966B75a8cDe --json
```

Default output:

```text
fixtures/deployments/public-agent-network-base-sepolia-plan.json
```

## Required Local Environment For Dry Run Or Broadcast

```powershell
$env:BASE_SEPOLIA_RPC_URL="<base-sepolia-rpc-url>"
$env:BASE_SEPOLIA_DEPLOYER_KEY_HEX="<0x-prefixed-32-byte-testnet-key>"
$env:BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS="0x69F55917209C446bf9d31D2903e01966B75a8cDe"
```

Optional source-verification key:

```powershell
$env:BASE_SEPOLIA_BASESCAN_API_KEY="<basescan-api-key>"
```

The Foundry script derives the address from `BASE_SEPOLIA_DEPLOYER_KEY_HEX` and rejects the run if it does not equal `BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS`.

## Dry Run

Run this before any broadcast:

```powershell
npm run public-agent-network:base-sepolia -- --json
```

Default dry-run artifact:

```text
fixtures/deployments/public-agent-network-base-sepolia.latest.json
```

## Broadcast

Broadcast only after the deployer is funded on Base Sepolia and the operator accepts testnet gas spend:

```powershell
npm run public-agent-network:base-sepolia:broadcast -- --json
```

After broadcast, keep the Foundry `broadcast/` folder ignored. Copy only non-secret facts into the deployment artifact or dated evidence doc:

- deployer address;
- contract names and addresses;
- deploy and smoke transaction hashes;
- deployment and smoke blocks;
- readback report paths;
- source-verification status per contract.

## Bounded Readback

Read back only explicit addresses and a bounded block range:

```powershell
npm run public-agent-network:base-sepolia:readback -- --rpc-url $env:BASE_SEPOLIA_RPC_URL --deployment-artifact fixtures/deployments/public-agent-network-base-sepolia.latest.json --from-block <deployBlock> --to-block <latestBlock>
```

Default outputs:

```text
fixtures/deployments/public-agent-network-base-sepolia-readback.latest.json
fixtures/deployments/public-agent-network-base-sepolia-readback.latest.md
```

The readback script requires Base Sepolia chain id `84532`, rejects broad scans, writes no RPC URLs or secrets, and fails unless it observes all required event groups:

- registry;
- launch;
- fuel;
- bond;
- swarm.

## Source Verification

Use the explorer key from local env only:

```powershell
forge verify-contract --watch --chain-id 84532 <address> <fully-qualified-contract> --etherscan-api-key $env:BASE_SEPOLIA_BASESCAN_API_KEY
```

Use the Foundry broadcast metadata for constructor arguments. Record `submitted`, `verified`, or `pending` for every deployed contract in the final evidence.

## Acceptance Checklist

- `npm run public-agent-network:base-sepolia:plan -- --deployer-address 0x69F55917209C446bf9d31D2903e01966B75a8cDe --json` writes the non-secret plan.
- Dry run rejects the wrong chain id and mismatched deployer key/address.
- Broadcast emits public-agent registry, launch, fuel, bond, receipt, and swarm events.
- Readback observes required event groups over an explicit bounded block range.
- Source verification is submitted or explicitly marked pending per contract.
- No private keys, RPC URLs, explorer API keys, or `.env` files are committed.
- Docs continue to state that this is Base Sepolia testnet evidence only.
