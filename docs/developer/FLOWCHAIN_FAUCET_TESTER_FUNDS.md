# FlowChain Faucet And Tester Funds

Status: local no-value faucet/test allocation guide.

## Local Faucet

The local runtime can queue no-value test credits for local accounts. Use this
only for local/private testing:

```powershell
npm run flowchain:faucet -- --account <account-id> --amount 100 --reason local-test --authorized-by <operator-id>
```

Read metadata:

```powershell
npm run flowchain:devkit -- faucet-events --json --limit 20
npm run flowchain:devkit -- wallet-balances --json --limit 20
```

Faucet/test credits are not production funds.

## Friends-And-Family Tester Funds

Before sharing accounts externally, run:

```powershell
npm run flowchain:tester:readiness -- -AllowBlocked
npm run flowchain:external-tester:packet -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
```

Only share a tester packet when public RPC, backup, bridge, no-secret, and
tester packet gates are ready or explicitly described as unavailable.

## Abuse Limits

For any public or semi-public allocation flow, require:

- per-account cap
- per-window cap
- audit log
- support contact
- emergency stop
- no private key collection
- no live bridge flow unless bridge readiness passes
