# Handoff

Current state:

- `npm run flowchain:production-l1:e2e` passes the mock-safe local path.
- Overall report status is `passed-with-live-blockers`.
- Strict live pilot is blocked by env names and missing subsystem proof commands.

Final commands:

```powershell
npm run flowchain:production-l1:e2e
npm run flowchain:bridge:live:check
npm run flowchain:emergency:stop-local
npm run flowchain:emergency:export-evidence
```

Reports and evidence:

- Final JSON report: `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`
- Readable summary: `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-summary.md`
- Evidence bundle: `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence.zip`
- Export bundle: `devnet/local/export/flowchain-local-state.zip`
- Bridge readiness report: `devnet/local/production-l1-e2e/bridge-live-readiness-report.json`

Local URLs:

- Dashboard: `http://127.0.0.1:5173/`
- Control-plane health: `http://127.0.0.1:8787/health`

Data directory:

```text
E:\FlowMemory\flowmemory-prod-ops\devnet\local
```

Required live env names:

- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH`
- `FLOWCHAIN_BASE8453_TOKEN_MODE`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`

Emergency commands:

```powershell
npm run flowchain:emergency:stop-local
npm run flowchain:bridge:emergency-stop
npm run flowchain:emergency:pause-bridge
npm run flowchain:emergency:export-evidence
npm run flowchain:emergency:print-recovery
```

Blocked reason for live pilot:

- Owner live env values are not present in this shell.
- `flowchain:real-value-pilot:contracts` is missing; owner `contracts`, issue #133.
- `flowchain:real-value-pilot:bridge` is missing; owner `bridge-relayer`, issue #138.
- `flowchain:real-value-pilot:runtime` is missing; owner `chain-runtime`, issue #134.

