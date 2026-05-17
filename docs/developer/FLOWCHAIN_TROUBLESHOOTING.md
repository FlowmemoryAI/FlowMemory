# FlowChain Troubleshooting

## RPC Connection Refused

Run:

```powershell
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:service:start -- -LiveProfile
```

The local RPC path is `http://127.0.0.1:8787/rpc`.

## 404 On Wallet Or RPC Path

Use `/rpc` for JSON-RPC, `/wallets/send` for private local wallet sends, and
`/wallets/create` for private local public-metadata wallet creation. Public
friends-and-family writes use `/tester/wallets/create` and
`/tester/wallets/send` with the owner-provided tester bearer token. Browser-safe
readiness endpoints are `/rpc/discover`, `/rpc/readiness`, and `/tester/status`.

## Chain Height Not Advancing

Run:

```powershell
npm run flowchain:devkit -- watch-height --json --seconds 30
npm run flowchain:service:monitor -- -AllowBlocked
```

If the height is stale, restart the live profile and rerun the service status
check.

## Missing Public RPC Env

Run:

```powershell
npm run flowchain:public-rpc:check -- -AllowBlocked
```

Configure only the named missing variables. Do not paste env values into chat,
docs, issue comments, or reports.

## Bridge Blocked On Base 8453 Inputs

Run:

```powershell
npm run flowchain:bridge:live:check -- -AllowBlocked
npm run flowchain:bridge:infra:check -- -AllowBlocked
```

Blocked means live bridge actions must stay disabled.

## Backup Path Missing

Run:

```powershell
npm run flowchain:backup:check -- -AllowBlocked
npm run flowchain:backup:restore:validate
```

The backup path must be configured by the owner before public RPC is considered
ready.

## Dev Pack Drift

Run:

```powershell
npm run flowchain:dev-pack:e2e
```

This regenerates `docs/sdk/RPC_REFERENCE.generated.md`, executes SDK/CLI/example
paths, checks required guides, and writes the current dev-pack report.
