# Token Proof

Status: implemented for private/local execution proof.

## Lifecycle

Token lifecycle transactions:

- `LaunchToken`
- `MintLocalTestToken`
- `TransferToken`

Token query state:

- `tokenDefinitions`
- `tokenBalances`
- `tokenMintReceipts`
- `tokenTransferReceipts`
- `executionReceipts`
- `executionEvents`

## Launch Rules

`LaunchToken` requires:

- deterministic token id from normalized symbol
- unique token id
- unique symbol
- symbol length 2 to 12 using uppercase alphanumeric characters
- nonempty name up to 64 characters
- decimals no greater than 18
- existing initial owner local account
- positive initial supply
- next expected account nonce

Launch assigns the full initial supply to the owner token balance and records an initial-supply mint receipt.

## Local Mint Rules

`MintLocalTestToken` is explicit local/test-mode state only. It requires an existing token, existing target account, positive amount, deterministic mint id, unique mint id, and next expected nonce. It updates total supply and records a mint receipt.

## Transfer Rules

`TransferToken` requires an existing token, existing source and destination accounts, positive amount, deterministic transfer id, available source token balance, and next expected source-account nonce. It updates both token balances and records a token transfer receipt.

## Events And Receipts

Successful token execution emits:

- `token_launched`
- `token_minted`
- `token_transfer`

Failed token transactions emit `execution_failed` and include an error code on the execution receipt. Covered codes include `invalid-token`, `insufficient-token-balance`, `duplicate-nonce`, and `stale-nonce`.

## Evidence

- Product flow launches `FLOWT`, transfers 10,000 units from Alice to Bob, then uses the token in a DEX pool.
- Negative tests cover invalid token id, invalid supply/amount, duplicate token identifiers, and insufficient token balance.
- Invariant tests assert total token units across balances match token supply after transfers and failed transactions.
- Execution report path: `devnet/local/execution-e2e/execution-e2e-report.json`.
