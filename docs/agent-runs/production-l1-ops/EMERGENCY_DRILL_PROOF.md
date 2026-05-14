# Emergency Drill Proof

Drill command set:

```powershell
npm run flowchain:emergency:stop-local
npm run flowchain:bridge:emergency-stop
npm run flowchain:emergency:export-evidence
npm run flowchain:emergency:print-recovery
```

Local stop behavior:

- Requests the local node stop file through the runtime wrapper.
- Lists control-plane/dashboard process stop commands for ports `8787` and `5173`.
- Can stop known port processes when the underlying script is run with `-StopKnownPorts`.

Bridge pause behavior:

- Routes through `flowchain-real-value-pilot-emergency-stop.ps1`.
- Live mode requires Base 8453 env, acknowledgement, caps, lockbox, and owner key.
- Dry-run mode is covered by `npm run flowchain:real-value-pilot:ops`.

Evidence:

- Final evidence export passed.
- Recovery commands are printed by `npm run flowchain:emergency:print-recovery`.

