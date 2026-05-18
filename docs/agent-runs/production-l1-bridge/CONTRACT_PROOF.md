# Contract Proof

Status: implemented and tested.

Changed contract:

- `contracts/bridge/BaseBridgeLockbox.sol`

Core behavior proved:

- Base deployment configuration is guarded for chain ID `8453` through deploy and observer scripts.
- Asset allowlist supports native ETH and ERC20 assets.
- Per-deposit cap is enforced for each configured asset.
- Total pilot cap is cumulative and does not reopen after release.
- Deposit pause blocks deposits.
- Emergency stop blocks deposits and releases.
- Owner controls token configuration, pause, emergency stop, and release authority updates.
- Release authority is separated from owner for release calls.
- Deposit accounting uses nonces and deterministic `depositId`.
- Release accounting uses `releaseId` replay protection.

Relayer-facing event:

```solidity
event BridgeDeposit(
    bytes32 indexed depositId,
    uint256 indexed sourceChainId,
    address indexed sender,
    address lockbox,
    address token,
    uint256 amount,
    bytes32 flowchainRecipient,
    uint256 nonce,
    bytes32 metadataHash,
    bytes32 pilotModeTag
);
```

Test proof:

- `forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol` passed with 16 tests.
- `forge test` passed with 85 tests.

Covered refusal branches:

- zero amount
- unsupported token
- exceeded per-deposit cap
- exceeded total pilot cap
- paused deposits
- emergency stop
- wrong release authority
- duplicate release
- mismatched release token
- unavailable release amount
- zero evidence hash
