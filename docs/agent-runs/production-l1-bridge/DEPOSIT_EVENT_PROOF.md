# Deposit Event Proof

Status: implemented.

The lockbox emits deterministic deposit event fields for the relayer:

- `sourceChainId`: emitted as `block.chainid`
- `lockbox`: emitted as the lockbox address
- `token`: zero address for native ETH or ERC20 token address
- `sender`: Base depositor
- `flowchainRecipient`: local/private FlowChain recipient bytes32
- `amount`: locked amount
- `nonce`: per-lockbox deposit nonce
- `depositId`: deterministic event key
- `metadataHash`: caller-supplied metadata commitment
- `pilotModeTag`: `keccak256("flowchain.base8453.owner-pilot.v0")`

The relayer also records receipt-derived fields that contracts cannot know during execution:

- `transactionHash`
- `logIndex`
- `blockNumber`
- `blockHash` when available
- `confirmations`

Deterministic deposit ID inputs:

```text
BRIDGE_DEPOSIT_SCHEMA_ID
block.chainid
lockbox address
sender
token
amount
flowchain recipient
nonce
metadata hash
pilot mode tag
```

Parser proof:

- Relayer tests decode the extended event signature:
  `BridgeDeposit(bytes32,uint256,address,address,address,uint256,bytes32,uint256,bytes32,bytes32)`.
- Legacy test fixtures remain accepted for prior POC lanes.
- The parser verifies the event lockbox data field matches the emitting log address for the extended event.
- The parser verifies the pilot mode tag for the extended event.
