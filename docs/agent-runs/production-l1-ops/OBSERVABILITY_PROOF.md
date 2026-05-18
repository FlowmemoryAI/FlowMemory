# Observability Proof

Local URLs:

- Dashboard: `http://127.0.0.1:5173/`
- Control-plane health: `http://127.0.0.1:8787/health`
- Control-plane state: `http://127.0.0.1:8787/state`

Status and log commands:

```powershell
npm run flowchain:doctor
npm run flowchain:node:status
npm run flowchain:node:logs
npm run flowchain:control-plane:smoke
npm run flowchain:dashboard:build
```

Predictable paths:

- Final reports/logs: `devnet/local/production-l1-e2e/`
- Node logs: `devnet/local/node/logs/`
- Node status: `devnet/local/node/node-status.json`
- Bridge mock output: `services/bridge-relayer/out/`
- Real-value pilot report: `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`
- Evidence bundle: `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence.zip`

Latest status:

- Control-plane smoke: passed.
- Dashboard build: passed.
- Node status: passed.
- Bridge live readiness: blocked on env names, not crashed.

