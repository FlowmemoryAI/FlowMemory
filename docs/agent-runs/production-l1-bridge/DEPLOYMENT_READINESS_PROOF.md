# Deployment Readiness Proof

Status: dry-run path implemented; broadcast path gated.

Script:

- `infra/scripts/bridge-base8453-deploy.ps1`

Commands:

```powershell
npm run bridge:deploy:dry-run
npm run bridge:deploy:base8453 -- -AcknowledgeBroadcast
```

Required env names:

- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_OPERATOR_ACK`

Required acknowledgement:

```text
I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT
```

Deployment checks:

- Verifies `eth_chainId == 0x2105` before broadcast.
- Derives owner from `FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY` locally through `cast wallet address`.
- Uses the same owner as initial release authority unless the script is extended later with a separate local owner-provided release key.
- Maps native ETH by setting `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN` to zero address.
- Maps ERC20 by setting `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN` to the token address.
- Writes a readiness artifact without secrets.

Current proof artifact:

- `services/bridge-relayer/out/base8453-deploy-readiness.json`

Current status:

- Dry-run completed as `missing-env-safe` because owner live env values were not present.
- No live deploy or contract verification was attempted without owner env.
