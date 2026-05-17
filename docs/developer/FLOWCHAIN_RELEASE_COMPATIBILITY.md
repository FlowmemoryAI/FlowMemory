# FlowChain Release And Compatibility

Status: compatibility guide for current local/private SDK and RPC.

## RPC Reference

Generate the reference from live discovery:

```powershell
npm run flowchain:dev-pack:e2e
```

Output:

```text
docs/sdk/RPC_REFERENCE.generated.md
```

Do not hand-edit the generated method table. Update the control-plane method
metadata and regenerate.

## Versioning Policy

- Additive read methods are minor SDK changes.
- Removing or renaming RPC methods is a breaking change.
- Changing a response schema name is a breaking change unless the old schema is
  still accepted by examples/tests.
- Public RPC eligibility changes must be reflected in `rpc_discover`,
  public deployment contract evidence, and docs.

## Compatibility Matrix

| Surface | Current status | Gate |
| --- | --- | --- |
| FlowChain-native JSON-RPC | Local/private available | `rpc_discover` |
| SDK client | Local/private available | `npm test --prefix services/flowchain-sdk` |
| Devkit CLI | Local/private available | `npm run flowchain:dev-pack:e2e` |
| Browser readiness example | Read-only local available | `GET /rpc/discover`, `GET /rpc/readiness` |
| Public RPC | Owner-input blocked | `npm run flowchain:public-rpc:check -- -AllowBlocked` |
| Base 8453 bridge pilot | Owner-input blocked | `npm run flowchain:bridge:live:check -- -AllowBlocked` |

## Release Gate

Before publishing developer-facing instructions, run:

```powershell
npm run flowchain:sdk:e2e
npm run flowchain:public-rpc:validate
npm run flowchain:tester:readiness -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```
