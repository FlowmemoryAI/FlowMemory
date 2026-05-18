# Credit Application Proof

Status: implemented and tested in local pilot state.

Credit path:

1. Observe Base deposit evidence.
2. Derive deterministic observation ID.
3. Derive deterministic replay key.
4. Derive deterministic credit ID.
5. Verify source chain is Base `8453`.
6. Verify source lockbox is approved.
7. Verify token is configured.
8. Verify amount is within the configured caps.
9. Apply local FlowChain credit state exactly once.
10. Write runtime handoff and application state.

Exactly-once state:

- State file: `services/bridge-relayer/out/real-value-pilot-e2e/bridge-credit-application-state.json`
- Replay key: `0xea93b7d168d2f1f6c4be4f95ba4d85aa2d07fc4298a720d180000a19d98481f0`
- First application: `applied`
- Same-event replay: `idempotent_replay`
- Duplicate fixture replay: rejected with `duplicate_replay_key`

Deterministic fixture E2E IDs:

- observation ID: `0x01d76831a495a9869e1f880ae44fdf6b382bc1a2c0fe593e5536a9538989b73b`
- credit ID: `0x6f9e131efd014f742a589e62393bce237d9daee3ef7cd4ef9c0b7f5e95d10dc6`

Local usage artifact:

- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-local-usage-proof.json`
- transfer ID: `0x7b0654d6bf64c91e835eebafd17cc1c6e55aa7b555d02f533a59170cab46be5b`
- credited wallet after credit: `20000000`
- credited wallet after prepared transfer: `10000000`
- second wallet after prepared transfer: `10000000`

Commands:

```powershell
npm run flowchain:bridge:local-credit:smoke
npm run flowchain:real-value-pilot:bridge
```
