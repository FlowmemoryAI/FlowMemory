# Emergency Proof

Emergency command family:

```powershell
npm run flowchain:emergency:stop-local
npm run flowchain:bridge:emergency-stop
npm run flowchain:emergency:pause-bridge
npm run flowchain:emergency:export-evidence
npm run flowchain:emergency:print-recovery
```

What each command does:

- `flowchain:emergency:stop-local`: requests local node stop and prints/manualizes control-plane and dashboard port stop commands unless `-StopKnownPorts` is explicitly passed to the script.
- `flowchain:bridge:emergency-stop`: routes to the guarded Base 8453 pause action.
- `flowchain:emergency:pause-bridge`: same guarded pause path.
- `flowchain:emergency:export-evidence`: writes a secret-scanned evidence bundle.
- `flowchain:emergency:print-recovery`: writes and prints recovery commands.

Latest evidence export:

```text
Bundle: devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence.zip
Status: passed
SHA256: 45295F89EDAAA1BFDCE7EE4A1E16AF285554CD12B2166682F456A353333B79FD
```
