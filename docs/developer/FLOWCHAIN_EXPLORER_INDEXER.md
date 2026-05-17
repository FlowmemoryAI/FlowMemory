# FlowChain Explorer And Indexer Guide

Status: local/private explorer/indexer integration guide.

## Core Reads

```powershell
npm run flowchain:devkit -- blocks --json --limit 20
npm run flowchain:devkit -- block --json --block <block-number-or-hash>
npm run flowchain:devkit -- transactions --json --limit 20
npm run flowchain:devkit -- transaction --json --tx <tx-id-or-hash>
npm run flowchain:devkit -- accounts --json --limit 20
npm run flowchain:devkit -- balance --json --account <account-id>
```

## Finality And Provenance

```powershell
npm run flowchain:devkit -- finality --json --limit 20
npm run flowchain:devkit -- finality-get --json --object <object-id>
```

Finality is local/devnet finality unless a future production consensus gate
adds a separate production finality contract.

## Bridge Explorer Rows

```powershell
npm run flowchain:devkit -- bridge-deposits --json --limit 20
npm run flowchain:devkit -- bridge-credits --json --limit 20
npm run flowchain:devkit -- bridge-credit-status --json --credit <credit-id>
npm run flowchain:devkit -- withdrawals --json --limit 20
```

Bridge rows must distinguish local/mock evidence from owner-configured live
pilot evidence.

## Stale Data Detection

Explorer views should poll `chain_status` and compare:

- current height
- finalized height
- state file write age
- node running flag
- control-plane readiness

If height does not advance or the state file is stale, show a stale-data state
instead of implying the chain is live.
