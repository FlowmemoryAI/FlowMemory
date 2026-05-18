# One Command Local Proof

Command:

```powershell
npm run flowchain:production-l1:e2e
```

Latest result:

- Mock-safe local path: passed.
- Prereq, init, node start, node status: passed.
- Wallet E2E and local transfer: passed.
- Product, token, and DEX: passed.
- Bridge mock pilot: passed.
- Control-plane smoke: passed.
- Dashboard build: passed.
- Export/import root comparison: passed.
- Restart recovery: passed.
- No-secret and unsafe-claim scans: passed.

The command writes:

- JSON report: `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`
- Readable summary: `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-summary.md`
- Evidence bundle: `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence.zip`
