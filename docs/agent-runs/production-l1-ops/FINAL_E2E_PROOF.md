# Final E2E Proof

Latest root command:

```powershell
npm run flowchain:production-l1:e2e
```

Result:

```text
FlowChain production-l1:e2e status: passed-with-live-blockers
Dashboard URL: http://127.0.0.1:5173/
Data directory: E:\FlowMemory\flowmemory-prod-ops\devnet\local
Final report: E:\FlowMemory\flowmemory-prod-ops\devnet\local\production-l1-e2e\flowchain-production-l1-e2e-report.json
Evidence bundle: E:\FlowMemory\flowmemory-prod-ops\devnet\local\production-l1-e2e\evidence\flowchain-production-l1-evidence.zip
Bridge live readiness command: npm run flowchain:bridge:live:check
```

Machine-readable report summary:

- Overall: `passed-with-live-blockers`.
- Mock-safe local path: `passed`.
- Live readiness: `blocked`.
- State root: `0x21be07858c24cc2ecb99fd5d2d0240aa251e13a0910455397855a993b549db6d`.
- Backup/restore root comparison: passed.
- No-secret scan: passed.
- Unsafe-claim scan: passed.

Strict live pilot remains blocked by missing owner/env inputs and missing subsystem proof commands:

- `flowchain:real-value-pilot:contracts`
- `flowchain:real-value-pilot:bridge`
- `flowchain:real-value-pilot:runtime`
