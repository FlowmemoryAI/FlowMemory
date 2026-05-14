# Mock Pilot E2E Proof

Status: passed without live RPC, live keys, or broadcast.

Command:

```powershell
npm run bridge:pilot:mock:e2e
```

Report:

- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json`

Artifacts:

- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-observation.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-credit.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-pilot-evidence.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-runtime-handoff.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-local-usage-proof.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-withdrawal-intent.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-withdrawal-authorization.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-release-evidence.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-replay-handoff.json`

Covered flow:

- Base `8453` mock deposit observed.
- Deterministic observation ID derived.
- Deterministic credit ID derived.
- Local credit applied once.
- Same-event replay returned idempotent status without double credit.
- Duplicate deposit replay was rejected.
- Local transfer handoff prepared for a second wallet.
- Product/DEX local gate linked through `npm run flowchain:product-e2e`.
- Withdrawal intent generated with Base recipient, asset, and amount.
- Companion withdrawal authorization generated with nonce, local chain ID, signed payload hash, and deterministic test signature.
- Release evidence generated for `releaseERC20`.
- Wrong-chain and unapproved-lockbox negative checks passed.

Report values:

- observation ID: `0x01d76831a495a9869e1f880ae44fdf6b382bc1a2c0fe593e5536a9538989b73b`
- credit ID: `0x6f9e131efd014f742a589e62393bce237d9daee3ef7cd4ef9c0b7f5e95d10dc6`
- withdrawal intent ID: `0x1ed8e1c5b59f306a3892e7a6befbbeeb4417cd6656d2ab51457ac5ab7ec16b0f`
- withdrawal authorization ID: `0x6dde86c11bc71f6d385e0dc2ba0d7874c7fb7ff2bff56d864014b30cb0b2c057`
- release evidence ID: `0x6dfe4e3d9b05aa930b164fffb69a3068a0b8609417d62233dba0fcaa47350685`
- local transfer ID: `0x7b0654d6bf64c91e835eebafd17cc1c6e55aa7b555d02f533a59170cab46be5b`
