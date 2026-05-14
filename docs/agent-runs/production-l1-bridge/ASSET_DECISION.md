# Asset Decision

Status: implemented.

The lockbox supports both native Base ETH and ERC20 custody paths. The owner pilot activates exactly one supported asset through configuration:

- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN=0x0000000000000000000000000000000000000000` means native ETH.
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN=<erc20-address>` means the allowlisted ERC20.

Why this decision fits the current architecture:

- `BaseBridgeLockbox.lockNative` already handles native deposits with `msg.value`.
- `BaseBridgeLockbox.lockERC20` already handles ERC20 deposits with allowance and `transferFrom`.
- `configureToken` stores per-asset allowlist status, per-deposit cap, total pilot cap, and cumulative deposited amount.
- Release uses separate paths: `releaseNative` and `releaseERC20`.

Refusal behavior:

- Live observation refuses deposits for tokens not listed through `--supported-token` or `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`.
- ERC20 deposits fail if the token is not allowlisted, amount is zero, allowance is missing, transfer fails, per-deposit cap is exceeded, or total cap is exceeded.
- Native deposits fail if native asset is not allowlisted, `msg.value` is zero, caps are exceeded, deposits are paused, or emergency stop is active.

Proof:

- `forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol` passed.
- `forge test` passed.
- Mock pilot evidence used ERC20 token `0x3333333333333333333333333333333333333333`.
- Native ETH support remains contract-tested and live-gated by choosing the zero address as the supported token.
