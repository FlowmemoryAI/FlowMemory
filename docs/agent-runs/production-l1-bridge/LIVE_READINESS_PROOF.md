# Live Readiness Proof

Status: fail-closed behavior proved without live secrets.

Command:

```powershell
npm run bridge:pilot:live:check
```

Report:

- `services/bridge-relayer/out/base8453-live-readiness-check.json`

Report status:

- `status`: `passed`
- `liveMode`: `false`
- `noSecrets`: `true`

The readiness check proved:

- Missing env values are reported by env name only.
- Missing `FLOWCHAIN_PILOT_OPERATOR_ACK` is rejected.
- Missing `FLOWCHAIN_PILOT_CONFIRMATIONS` is rejected.
- Missing `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN` is rejected.
- Broad block scans are rejected.
- Unapproved lockbox addresses are rejected.
- Wrong chain IDs are rejected before log scanning.

Owner acknowledgement value:

```text
I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT
```

Current live blocker:

- Owner live RPC URL, deployer key, lockbox address, supported token, caps, confirmation depth, bounded block range, and acknowledgement were not present in the worktree.
- Therefore no live Base transaction was executed.
