# Base Sepolia Deployment Rehearsal

Status: V0 public testnet rehearsal path.

This is not a production deployment guide, production mainnet guide, token
launch guide, custody guide, bridge guide, verifier-network guide, or
production Uniswap v4 hook guide.

## Goal

Use Base Sepolia to rehearse the current V0 contract package end to end:

1. generate a non-secret deployment plan;
2. run a Foundry dry run with explicit local env values;
3. optionally broadcast to Base Sepolia after operator approval;
4. emit one tiny Rootfield/FlowPulse write path;
5. read the resulting FlowPulse logs with the Base Sepolia reader;
6. persist indexer state and checkpoint output;
7. record verification, rollback, and boundary notes.

## Environment

Use an ignored `.env` file or shell variables only. Do not paste real values into
docs, GitHub issues, PR comments, screenshots, or committed artifacts.

Required for dry-run or broadcast:

```powershell
$env:BASE_SEPOLIA_RPC_URL="<base-sepolia-rpc-url>"
$env:BASE_SEPOLIA_DEPLOYER_KEY_HEX="<0x-prefixed-32-byte-testnet-key>"
```

Optional:

```powershell
$env:BASE_SEPOLIA_BASESCAN_API_KEY="<basescan-api-key>"
$env:BASE_SEPOLIA_FLOWPULSE_ADDRESSES="<comma-separated-addresses-after-deploy>"
$env:BASE_SEPOLIA_FROM_BLOCK="<first-deploy-or-smoke-block>"
$env:BASE_SEPOLIA_TO_BLOCK="<latest-reviewed-block>"
$env:BASE_SEPOLIA_FINALIZED_BLOCK="<safe-finalized-block>"
```

The repo also accepts `BASESCAN_API_KEY` as a fallback explorer key name. The
scripts redact key presence and never write the key value.

## Plan-Only Command

This command requires no private key and writes the non-secret plan artifact:

```powershell
npm run deploy:base-sepolia:plan -- --json
```

Default output:

```text
fixtures/deployments/base-sepolia-rehearsal-plan.json
```

The plan records:

- required env names;
- contract names deployed by `DeployLaunchCandidate`;
- the redacted Foundry command;
- write smoke command templates;
- readback command templates;
- explorer verification command template;
- rollback notes and blocked claims.

## Dry Run

Run this before any Base Sepolia broadcast:

```powershell
npm run deploy:base-sepolia -- --json
```

Default output when the dry run succeeds:

```text
fixtures/deployments/base-sepolia-rehearsal.latest.json
```

The Foundry script now rejects the wrong chain id and expects Base Sepolia
`84532`.

## Optional Broadcast

Broadcast only after the operator approves testnet gas spend and confirms the
deployer key is a testnet key:

```powershell
npm run deploy:base-sepolia:broadcast -- --json
```

After broadcast, copy only non-secret facts into a dated deployment doc:

- deployer address;
- contract names and addresses;
- deploy transaction hashes;
- deployment blocks;
- source verification status;
- smoke transaction hashes;
- reader checkpoint paths.

## Write Smoke

Use small deterministic testnet values. These commands are templates; replace
addresses and hashes from the deployment artifact or Foundry broadcast output.

```powershell
cast send <RootfieldRegistry> "registerRootfield(bytes32,bytes32,bytes32,string)" <rootfieldId> <schemaHash> <metadataHash> "ipfs://flowmemory-base-sepolia-rehearsal" --rpc-url $env:BASE_SEPOLIA_RPC_URL --private-key $env:BASE_SEPOLIA_DEPLOYER_KEY_HEX
```

```powershell
cast send <RootfieldRegistry> "submitRoot(bytes32,bytes32,bytes32,bytes32,string)" <rootfieldId> <root> <artifactCommitment> <parentPulseId> "ipfs://flowmemory-base-sepolia-rehearsal-root" --rpc-url $env:BASE_SEPOLIA_RPC_URL --private-key $env:BASE_SEPOLIA_DEPLOYER_KEY_HEX
```

Optional hook-adapter smoke:

```powershell
cast send <FlowMemoryHookAdapter> "afterSwap(address,bytes32,bytes32,bytes32,bytes)" <sender> <poolId> <rootfieldId> <commitment> 0x1234 --rpc-url $env:BASE_SEPOLIA_RPC_URL --private-key $env:BASE_SEPOLIA_DEPLOYER_KEY_HEX
```

These writes are for public testnet rehearsal only. They do not prove
production hook readiness.

## Readback

Read contract state:

```powershell
cast call <RootfieldRegistry> "getRootfield(bytes32)" <rootfieldId> --rpc-url $env:BASE_SEPOLIA_RPC_URL
```

Read FlowPulse logs:

```powershell
npm run index:base-sepolia -- --rpc-url $env:BASE_SEPOLIA_RPC_URL --address <RootfieldRegistry> --address <FlowMemoryHookAdapter> --from-block <deployBlock> --to-block <latestBlock> --finalized-block <safeFinalizedBlock>
```

Resume from the durable checkpoint:

```powershell
npm run index:base-sepolia -- --rpc-url $env:BASE_SEPOLIA_RPC_URL --address <RootfieldRegistry> --address <FlowMemoryHookAdapter> --resume-from-checkpoint --to-block <latestBlock>
```

The reader:

- requires an explicit RPC URL;
- rejects non-Base-Sepolia chain ids;
- rejects broad scans above the configured span;
- stores state and checkpoint JSON atomically;
- records `lastIndexedBlock`, `highestObservedBlock`, `nextFromBlock`, and
  `emptyRange`;
- does not write RPC URLs, private keys, or explorer API keys.

## Source Verification

Use the explorer key only from local env:

```powershell
forge verify-contract --chain-id 84532 <address> <ContractName> --etherscan-api-key $env:BASE_SEPOLIA_BASESCAN_API_KEY
```

Record verification result per contract in the dated deployment doc. A verified
Base Sepolia source is still a testnet fact, not production approval.

## Rollback And Recovery

- If the dry run fails, fix locally and rerun the plan plus dry run.
- If broadcast fails before all contracts deploy, discard the partial address
  set unless a reviewer explicitly approves documenting it as failed evidence.
- If write smoke fails, record the transaction hash and revert reason, then use
  readback commands to distinguish contract failure from RPC/nonce failure.
- V0 has no proxy rollback. Stop using an address set by marking it superseded
  in `docs/DEPLOYMENTS/`.
- Never reuse a deployer key that was exposed on screen or copied into docs.

## Acceptance Checklist

- `npm run deploy:base-sepolia:plan -- --json` writes a non-secret plan.
- `npm run deploy:base-sepolia -- --json` dry-runs on chain id `84532`.
- Optional broadcast is approved and produces dated deployment facts.
- At least one Rootfield write emits FlowPulse on Base Sepolia.
- `npm run index:base-sepolia` persists state and checkpoint output.
- The checkpoint includes resume data and no secret material.
- Source verification is recorded or explicitly marked pending.
- `docs/CURRENT_STATE.md` is updated after any real broadcast.
- No production/mainnet/user-funds claim is made.
