# Replay Proof

Nonce and replay rules implemented for the production-L1 crypto surface:

- Account nonce replay key:
  `accountNonceReplayKey({ chainId, networkProfile, accountId, nonce })`
- Role-scoped nonce replay key:
  `roleScopedNonceReplayKey({ chainId, networkProfile, accountId, signerRole, nonce })`
- Bridge source event replay key:
  `bridgeSourceEventReplayKey(sourceEvent)`
- Withdrawal intent replay key:
  `withdrawalIntentReplayKey(withdrawalIntentInput)`
- Finality vote replay key:
  `finalityVoteReplayKey({ chainId, validatorAccountId, blockHash, round, voteType })`

Runtime validation rejects:

- stale nonce: `stale-nonce`
- duplicate nonce: `duplicate-nonce`
- duplicate transaction ID: `duplicate-tx-id`
- duplicate bridge source event: `duplicate-bridge-source-event`

The exact rejection vectors are in:

- `crypto/fixtures/production-l1-vectors.json`

Validation command:

```powershell
npm run validate:production-l1-crypto --prefix crypto
```
