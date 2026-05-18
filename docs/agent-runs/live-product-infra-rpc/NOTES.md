# FlowChain Live Infra RPC Notes

## Design Notes

- Public RPC readiness must never infer public safety from local defaults. The control plane default remains `127.0.0.1`.
- `FLOWCHAIN_RPC_PUBLIC_URL` is treated as a secret-adjacent deployment value for output purposes. Reports record whether it is configured and valid, but do not print it.
- Public mode requires HTTPS and `FLOWCHAIN_RPC_TLS_TERMINATED=true`. Explicit local URLs are allowed for local sanity checks but do not satisfy public readiness.
- CORS wildcard origins are rejected for public mode.
- Rate limiting is enforced as a required owner/proxy configuration input. The readiness gate verifies the numeric contract; the reverse proxy enforces it.
- Backups are verified by writing and reading a state backup artifact under `FLOWCHAIN_RPC_STATE_BACKUP_PATH` without printing that path.
- Base 8453 readiness checks may call read-only RPC methods such as `eth_chainId` and `eth_getCode`. They must not broadcast.

## Live Product E2E Integration

This branch adds `npm run flowchain:live-infra:check`. A later verification owner can integrate it into the final aggregate command by adding this step before any live bridge credit/spend proof:

```powershell
npm run flowchain:live-infra:check
```

That final aggregate must still fail closed until its other wallet, bridge credit, desktop/mobile, SDK, and verification inputs are configured and proven.
