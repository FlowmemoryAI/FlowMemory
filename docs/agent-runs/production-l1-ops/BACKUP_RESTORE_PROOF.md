# Backup Restore Proof

Commands:

```powershell
npm run flowchain:export
npm run flowchain:import -- --BundlePath devnet/local/export/flowchain-local-state.zip -StatePath devnet/local/production-l1-e2e/imported-state.json -Force
npm run flowchain:restart:verify
```

Latest comparison:

```text
Original state root: 0x21be07858c24cc2ecb99fd5d2d0240aa251e13a0910455397855a993b549db6d
Imported state root: 0x21be07858c24cc2ecb99fd5d2d0240aa251e13a0910455397855a993b549db6d
Status: passed
```

Evidence:

- `devnet/local/export/flowchain-local-state.zip`
- `devnet/local/production-l1-e2e/export-import-root-compare.json`
- `devnet/local/node-smoke/one-node-smoke-report.json`
