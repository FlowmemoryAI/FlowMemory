# Withdraw Release Proof

Status: implemented for pilot evidence and contract release checks.

Canonical withdrawal intent fields:

- `withdrawalIntentId`
- `creditId`
- `depositId`
- `sourceChainId`
- `destinationChainId`
- `token`
- `amount`
- `flowchainAccount`
- `baseRecipient`
- `status`
- `requestedAt`

Pilot withdrawal authorization fields:

- `authorizationId`
- `withdrawalIntentId`
- `creditId`
- `depositId`
- `flowchainChainId`
- `destinationChainId`
- `token`
- `amount`
- `flowchainAccount`
- `baseRecipient`
- `withdrawalNonce`
- `signedBy`
- `signatureScheme`
- `signedPayloadHash`
- `signature`

Deterministic fixture withdrawal proof:

- artifact: `services/bridge-relayer/out/real-value-pilot-e2e/bridge-withdrawal-intent.json`
- authorization artifact: `services/bridge-relayer/out/real-value-pilot-e2e/bridge-withdrawal-authorization.json`
- withdrawal intent ID: `0x1ed8e1c5b59f306a3892e7a6befbbeeb4417cd6656d2ab51457ac5ab7ec16b0f`
- authorization ID: `0x6dde86c11bc71f6d385e0dc2ba0d7874c7fb7ff2bff56d864014b30cb0b2c057`
- nonce: `1`
- local chain ID: `flowchain-local-pilot-v0`
- Base recipient: `0x4444444444444444444444444444444444444444`
- signature scheme: `flowchain-pilot-deterministic-test-signature-v0`

Release evidence:

- artifact: `services/bridge-relayer/out/real-value-pilot-e2e/bridge-release-evidence.json`
- release evidence ID: `0x6dfe4e3d9b05aa930b164fffb69a3068a0b8609417d62233dba0fcaa47350685`
- method: `releaseERC20`
- broadcast: `false`

Contract checks:

- wrong release authority rejected
- duplicate release rejected
- emergency stop blocks release
- pause does not block authorized release, by design, so the owner can recover during deposit pause
- release requires nonzero evidence hash

Live boundary:

- Fixture authorization signatures are deterministic test evidence.
- A live owner pilot should source the local account signature from the wallet/runtime path and pair it with the canonical withdrawal intent before any operator release.
