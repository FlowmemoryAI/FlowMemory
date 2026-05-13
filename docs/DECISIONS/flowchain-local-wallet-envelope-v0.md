# FlowChain Local Wallet And Transaction Envelope V0

Status: accepted for private/local testnet package.

Date: 2026-05-13

## Decision

FlowChain private/local testnet transactions use a crypto-package envelope named
`flowchain.local_transaction_envelope.v0`.

The envelope signs:

- `domain = flowchain.local.v0.transaction-envelope`
- `chainId`
- `nonce`
- public signer id and signer key id
- signer role
- canonical JSON `payloadHash`
- issuance and expiry timestamps
- secp256k1 signature over the local EIP-712 style digest

The envelope keeps the devnet transaction object at `payload.tx`. Consumers
validate the envelope first, then pass `payload.tx` to the existing
`crates/flowmemory-devnet` transaction path. This avoids a second devnet or
second object model.

Local test keys live in an encrypted vault managed by the existing `crypto/`
package. The vault uses scrypt plus AES-256-GCM. Public account metadata is
exported separately as `flowchain.local_wallet_public_metadata.v0`.

## Rationale

The private/local testnet needs real signing and signer display without making a
production wallet claim. Binding domain, chain id, nonce, signer metadata, and
payload hash gives the devnet and control-plane agents enough information to
reject wrong-network, wrong-domain, wrong-signer, and replayed local
transactions.

Preserving `payload.tx` keeps the handoff compatible with the current Rust
devnet transaction model.

## Boundaries

- No production custody claim.
- No tokenomics or production bridge readiness claim.
- No private key in committed fixtures or public metadata exports.
- No production key recovery, hardware wallet integration, or audited wallet
  claim.
- Bridge objects are local/private testnet accounting commitments only.

## Evidence

The crypto package now includes positive and negative vectors for local
transaction envelopes and wallet public metadata. The required commands are:

```powershell
npm test --prefix crypto
npm run validate:vectors --prefix crypto
npm run wallet:create --prefix crypto
npm run wallet:sign --prefix crypto
npm run wallet:verify --prefix crypto
```
