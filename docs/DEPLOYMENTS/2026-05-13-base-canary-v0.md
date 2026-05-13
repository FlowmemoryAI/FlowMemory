# Base Canary V0 Deployment

Date: 2026-05-13

Status: live Base mainnet canary deployment for V0 testing only.

This is not a production launch, production L1 deployment, token launch,
production verifier network, or production Uniswap v4 hook deployment.

## Network

- Network: Base mainnet
- Chain id: `8453`
- RPC used for deployment/testing: public Base RPC
- Deployer: `0x3A6fBA5a78216ba3a8DA8d8F501dee2C8186aFf9`
- Starting balance observed before dry run: `0.005451853012787615 ETH`
- Balance observed after deploy and smoke actions: `0.005423591837039270 ETH`
- Approximate total ETH spent by deploy plus smoke actions: `0.000028261175748345 ETH`

Private key material was loaded from a local ignored environment file and was
not committed.

## Deployed Contracts

| Contract | Address | Deploy tx | Block |
| --- | --- | --- | --- |
| `RootfieldRegistry` | `0x2a7ADd68a1d45C3251E2F92fFe4926124654a97C` | `0x9ef9cb563646921e8f8dd71ad237054b8ee5b0c8e8ecc0c3b1577661844d6108` | `45955460` |
| `FlowMemoryHookAdapter` | `0x179Df6d52e9DeF5D02704583a2E4E5a9FF427245` | `0xab22f1b9a19c090c63d4b3a4e100cf80571f5142ab91620fbc76d739d1f318b9` | `45955461` |
| `ArtifactRegistry` | `0x8F074d0F4e66975b740A4b7a316330c9660a485E` | `0xbd07e7d0280a20344521628b13353152da859e62fdcdb4355bf04b50a4176b0b` | `45955462` |
| `CursorRegistry` | `0x3360689009685eade15c876855D24161b05829C1` | `0x7eecbb949a617bff8fc8c0749a3332e1e2d2fe7b17f0cf3d7522155f5675cee9` | `45955463` |
| `ReceiptVerifier` | `0x94ba7aA4562f8F8528C327378F6352350f6ddB5B` | `0x3b29454ebb4104e38a0f886a4a370f26d3e3bc5ab22bbfb921374fa904e38e95` | `45955464` |
| `WorkerRegistry` | `0xa8c07eF53Eeb4e57297ee35025a9cD5303fCCD29` | `0x213a1ba85d6e998937c907699be83b7cd7db9eba4e43f937f94ad7b62bf3cfde` | `45955465` |
| `VerifierRegistry` | `0xAf920ca7436Bb72172E27C96E0B716f01dcC5DBd` | `0x87696577de6522f885a67c9df98fd8942387e7e7c735f3215f067b2cbc913d2f` | `45955466` |
| `WorkReceiptRegistry` | `0x2874cee0D581E4562ac9015BfCf330f1ea58a1F3` | `0xa278992a28c2a1ad9e4c78998dbbfb43399e55182ca93f8aac40e9447b2f854f` | `45955467` |
| `VerifierReportRegistry` | `0x95bC7455AdFD60e1B908ba455c25Ae732C1Ef996` | `0x9def1a9338bf65e04bc43fd3f4ef1bb973ebdf1ee4b351a77157c396da6af074` | `45955468` |
| `WorkDebtScheduler` | `0xa752e9bC7fAf39f659110D8Cf408E7707db94E34` | `0x139e3b89b0c674c6031d34fbfafb2649e114443ed7b98b9722d59bc19ffb6bdc` | `45955469` |

All 10 deployed addresses returned non-empty bytecode through `cast code`.

## Smoke Actions

Rootfield id:

```text
0x19c830e926bfd3ce06d71ed0ef2e90ddc73accf4367b0defea835dc1cd3b3114
```

### Rootfield Registration

- Transaction: `0x994b98b1cff0c897d75b62cf7c95340f74a59d0c208af68f1dea2d161b80cf00`
- Block: `45955506`
- FlowPulse pulse id: `0xa62ffb4b36a415032949138edbdcba5005de2e35952df88bdf592d4266184b87`
- Pulse type: `1` / `ROOTFIELD_REGISTERED`

### Root Submission

- Transaction: `0x24a43789ef489dd6c697567466944a210273e46c333e7be878cda6df9acb8e7a`
- Block: `45955533`
- FlowPulse pulse id: `0x72407268a2ea62659d6b0f62800931936cc6ea7ea5f5b6db91801ba2f8b43eab`
- Pulse type: `2` / `ROOT_COMMITTED`
- Latest root after smoke action:
  `0x4a7b8601c06c20bcc7b69c05c51980c12dbd50cbd95a59f460d40555bfc37ce3`

### Swap-Memory Signal

- Transaction: `0xaee21f6d0e9df1a45eae0c7714a4f8eae7fb72afbb07dd67b3a1f0ff724a014f`
- Block: `45955535`
- FlowPulse pulse id: `0x16c2adf5f3e46ee91d16a432d2420c566851b311e767860cab99068dcaca2591`
- Pulse type: `4` / `SWAP_MEMORY_SIGNAL`
- Commitment:
  `0x30055afe075a7c6ea8557ea3a2d3c7012d9d558ebda95803726179355f98ede9`

## State Readback

`RootfieldRegistry.getRootfield(rootfieldId)` returned:

```text
owner:        0x3A6fBA5a78216ba3a8DA8d8F501dee2C8186aFf9
schemaHash:   0x0b4537a7fa7cdd45fd6ff2052f1e4f9087a40b09fb6fe06a686ac67ac96fa5c3
metadataHash: 0x5f2a82ffa386793a2a67971ab801b2633b76954a95ee873e463730e6442ef90d
latestRoot:   0x4a7b8601c06c20bcc7b69c05c51980c12dbd50cbd95a59f460d40555bfc37ce3
pulseCount:   2
rootCount:    1
active:       true
```

## Important Gaps Found

1. The checked-in live reader is Base Sepolia-only and intentionally rejects
   Base mainnet chain id `8453`. A guarded Base canary reader is needed before
   the dashboard can ingest live mainnet canary logs.
2. The dashboard still consumes generated fixtures. It does not yet ingest a
   deployment artifact plus live read output.
3. Contract source verification is not automated for all deployed contracts.
4. `FlowMemoryHookAdapter` is still an adapter scaffold. It is not a production
   Uniswap v4 hook wired into PoolManager permissions.
5. Ownership is still direct deployer ownership where applicable. There is no
   multisig, governance, recovery, or operational key policy.
6. Verifier and worker registry flows are deployed, but live verifier report
   submission, report signing, and verifier economics are not built.

## Notes

The first registration command encountered a public-RPC nonce race after the
transaction landed. The chain state and FlowPulse log were checked directly
before subsequent smoke actions were sent.
