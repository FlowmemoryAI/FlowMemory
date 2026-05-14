import { bytesToHex } from "./encoding.js";
import { signDigest, publicKeyFromPrivateKey } from "./attestations.js";
import {
  LOCAL_ALPHA_BRIDGE_STATUSES,
  LOCAL_ALPHA_FINALITY_STATES,
  ZERO_BYTES32
} from "./constants.js";
import {
  bridgeCreditId,
  bridgeWithdrawalIntentId,
  finalityReceiptId,
  localAlphaObjectId,
  localBalanceRecordId,
  productAddLiquidityId,
  productPoolCreateId,
  productRemoveLiquidityId,
  productSwapId,
  productTokenLaunchId,
  productTransferId
} from "./objects.js";
import { buildUnsignedLocalTransactionEnvelope } from "./transactions.js";
import {
  accountNonceReplayKey,
  bridgeSourceEventReplayKey,
  finalityVoteReplayKey,
  flowchainAccountStateRoot,
  flowchainBlockHash,
  flowchainBridgeCreditId,
  flowchainBridgeObservationId,
  flowchainDexStateRoot,
  flowchainEventRoot,
  flowchainFinalityReceiptId,
  flowchainReceiptRoot,
  flowchainTokenStateRoot,
  flowchainTransactionId,
  flowchainTxRoot,
  flowchainWithdrawalIntentId,
  roleScopedNonceReplayKey,
  withdrawalIntentReplayKey
} from "./production-l1.js";
import {
  flowchainAccountId,
  flowchainPublicAccountMetadata,
  flowchainSignerKeyId
} from "./identity.js";
import { canonicalJsonHash, keccakUtf8 } from "./hashes.js";
import { verifyFlowchainEnvelope } from "./runtime-validation.js";

const CHAIN_ID = "31337";
const NETWORK_PROFILE = "local-chain";
const ISSUED_AT_UNIX_MS = "1778702400000";
const EXPIRES_AT_UNIX_MS = "1778706000000";
const BASE_8453_CHAIN_ID = "8453";

export async function buildProductionL1Vectors() {
  const accounts = {
    user: account("user", 1),
    recipient: account("user", 2),
    validator: account("validator", 3),
    bridgeRelayer: account("bridgeRelayer", 4),
    bridgeReleaseAuthority: account("bridgeReleaseAuthority", 5),
    emergencyOperator: account("emergencyOperator", 6)
  };

  const assets = {
    native: keccakUtf8("flowchain.asset.native-test-unit.v0"),
    token: keccakUtf8("flowchain.asset.token.launch-demo.v0")
  };
  const poolId = keccakUtf8("flowchain.pool.native-token.demo");
  const bridgeSourceEvent = {
    sourceChainId: BASE_8453_CHAIN_ID,
    lockbox: "0x1111111111111111111111111111111111111111",
    token: "0x2222222222222222222222222222222222222222",
    depositor: "0x3333333333333333333333333333333333333333",
    recipient: accounts.user.accountId,
    amount: "25000000",
    txHash: keccakUtf8("base-8453-lock-tx"),
    logIndex: "7",
    blockNumber: "45955540",
    eventNonce: "1"
  };
  const bridgeObservationId = flowchainBridgeObservationId(bridgeSourceEvent);
  const canonicalBridgeCreditId = flowchainBridgeCreditId({
    observationId: bridgeObservationId,
    localRecipient: accounts.user.accountId,
    localChainId: CHAIN_ID,
    creditAmount: bridgeSourceEvent.amount
  });
  const depositId = keccakUtf8("bridge-deposit:base-8453:demo");

  const documents = {
    walletTransfer: productTransferDocument({
      fromAccountId: accounts.user.accountId,
      toAccountId: accounts.recipient.accountId,
      assetId: assets.native,
      amount: "1000000",
      accountNonce: "1",
      deadlineBlock: "120",
      memoHash: keccakUtf8("wallet transfer")
    }),
    faucetFunding: localBalanceRecordDocument({
      accountId: accounts.user.accountId,
      assetId: assets.native,
      availableAmount: "100000000",
      lockedAmount: "0",
      lastCreditId: keccakUtf8("faucet-credit"),
      lastWithdrawalId: ZERO_BYTES32,
      stateRoot: keccakUtf8("state:faucet-funded"),
      updatedAtBlockNumber: "1",
      nonce: keccakUtf8("local-balance:faucet:nonce")
    }),
    tokenLaunch: productTokenLaunchDocument({
      issuerAccountId: accounts.user.accountId,
      tokenId: assets.token,
      symbolHash: keccakUtf8("FLOWT"),
      nameHash: keccakUtf8("FlowChain Test Token"),
      metadataHash: keccakUtf8("token metadata"),
      decimals: 6,
      initialSupply: "1000000000",
      recipientAccountId: accounts.user.accountId,
      accountNonce: "2",
      launchPolicyHash: keccakUtf8("launch policy")
    }),
    tokenTransfer: productTransferDocument({
      fromAccountId: accounts.user.accountId,
      toAccountId: accounts.recipient.accountId,
      assetId: assets.token,
      amount: "5000000",
      accountNonce: "3",
      deadlineBlock: "140",
      memoHash: keccakUtf8("token transfer")
    }),
    poolCreate: productPoolCreateDocument({
      creatorAccountId: accounts.user.accountId,
      poolId,
      baseAssetId: assets.native,
      quoteAssetId: assets.token,
      feeBps: 30,
      tickSpacing: 1,
      metadataHash: keccakUtf8("pool metadata"),
      accountNonce: "4"
    }),
    addLiquidity: productAddLiquidityDocument({
      providerAccountId: accounts.user.accountId,
      poolId,
      baseAmount: "25000000",
      quoteAmount: "250000000",
      minLiquidityTokens: "1",
      deadlineBlock: "160",
      accountNonce: "5"
    }),
    removeLiquidity: productRemoveLiquidityDocument({
      providerAccountId: accounts.user.accountId,
      poolId,
      liquidityTokens: "1000",
      minBaseAmount: "1",
      minQuoteAmount: "1",
      deadlineBlock: "180",
      accountNonce: "6"
    }),
    swap: productSwapDocument({
      traderAccountId: accounts.user.accountId,
      poolId,
      assetInId: assets.native,
      assetOutId: assets.token,
      amountIn: "100000",
      minAmountOut: "900000",
      deadlineBlock: "200",
      accountNonce: "7"
    }),
    bridgeCredit: bridgeCreditDocument({
      depositId,
      recipient: accounts.user.accountId,
      assetId: assets.token,
      amount: bridgeSourceEvent.amount,
      creditedAtBlockNumber: "8",
      creditedAtUnixMs: ISSUED_AT_UNIX_MS,
      status: "credited",
      statusCode: LOCAL_ALPHA_BRIDGE_STATUSES.credited,
      nonce: keccakUtf8("bridge-credit:nonce")
    }),
    withdrawalIntent: bridgeWithdrawalIntentDocument({
      creditId: canonicalBridgeCreditId,
      depositId,
      sourceChainId: Number(CHAIN_ID),
      destinationChainId: 8453,
      token: bridgeSourceEvent.token,
      amount: "10000000",
      flowchainAccount: accounts.user.accountId,
      baseRecipient: "0x4444444444444444444444444444444444444444",
      status: "requested",
      requestedAt: "2026-05-13T23:00:00.000Z",
      testMode: true,
      broadcast: false,
      releasePolicy: "test_record_only",
      productionReady: false
    }),
    finality: finalityReceiptDocument({
      receiptId: keccakUtf8("receipt:finality"),
      reportId: keccakUtf8("report:finality"),
      challengeRoot: keccakUtf8("challenge-root:empty"),
      finalityState: "finalized",
      finalityStateCode: LOCAL_ALPHA_FINALITY_STATES.finalized,
      finalizedAtUnixMs: ISSUED_AT_UNIX_MS,
      finalizedBlockNumber: "9",
      finalizedBlockHash: keccakUtf8("block:9"),
      policyHash: keccakUtf8("finality-policy")
    })
  };

  const positives = [
    await signedVector("wallet-transfer", documents.walletTransfer, accounts.user, "1", "wallet_transfer"),
    await signedVector("faucet-test-funding", documents.faucetFunding, accounts.emergencyOperator, "2", "faucet_test_funding"),
    await signedVector("token-launch", documents.tokenLaunch, accounts.user, "3", "token_launch"),
    await signedVector("token-transfer", documents.tokenTransfer, accounts.user, "4", "token_transfer"),
    await signedVector("pool-create", documents.poolCreate, accounts.user, "5", "pool_create"),
    await signedVector("add-liquidity", documents.addLiquidity, accounts.user, "6", "add_liquidity"),
    await signedVector("remove-liquidity", documents.removeLiquidity, accounts.user, "7", "remove_liquidity"),
    await signedVector("swap", documents.swap, accounts.user, "8", "swap"),
    await signedVector("bridge-credit-authority", documents.bridgeCredit, accounts.bridgeReleaseAuthority, "9", "bridge_credit"),
    await signedVector("withdrawal-intent", documents.withdrawalIntent, accounts.user, "10", "withdrawal_intent"),
    await signedVector("validator-finality", documents.finality, accounts.validator, "11", "validator_finality")
  ];

  const hashHelpers = buildHashHelperVectors({
    positives,
    accounts,
    assets,
    poolId,
    bridgeSourceEvent,
    bridgeObservationId,
    canonicalBridgeCreditId
  });
  const negatives = buildNegativeVectors({ positives, accounts, bridgeSourceEvent });

  return {
    schema: "flowmemory.crypto.production-l1-vectors.v0",
    chainId: CHAIN_ID,
    networkProfile: NETWORK_PROFILE,
    issuedAtUnixMs: ISSUED_AT_UNIX_MS,
    expiresAtUnixMs: EXPIRES_AT_UNIX_MS,
    boundary: "Deterministic local/private production-L1-shaped crypto vectors. Fixtures contain public test metadata, documents, signatures, and expected validation failures only.",
    accounts: Object.fromEntries(
      Object.entries(accounts).map(([name, value]) => [name, value.publicMetadata])
    ),
    bridgeSourceEvent,
    hashHelpers,
    positive: positives,
    negative: negatives
  };
}

function account(role, index) {
  const privateKey = deterministicTestPrivateKey(index);
  const publicKey = publicKeyFromPrivateKey(privateKey);
  const publicMetadata = flowchainPublicAccountMetadata({
    publicKey,
    role,
    label: `production-l1-${role}`,
    createdAtUnixMs: ISSUED_AT_UNIX_MS
  });
  return {
    role,
    privateKey,
    publicKey: publicMetadata.publicKey,
    accountId: flowchainAccountId({ publicKey, role }),
    signerKeyId: flowchainSignerKeyId({ publicKey }),
    publicMetadata
  };
}

async function signedVector(name, document, signer, nonce, payloadType) {
  const unsigned = buildUnsignedLocalTransactionEnvelope({
    document,
    chainId: CHAIN_ID,
    nonce,
    signerId: signer.accountId,
    signerKeyId: signer.signerKeyId,
    signerRole: signer.role,
    publicKey: signer.publicKey,
    issuedAtUnixMs: ISSUED_AT_UNIX_MS,
    expiresAtUnixMs: EXPIRES_AT_UNIX_MS,
    networkProfile: NETWORK_PROFILE,
    payloadType
  });
  const signature = await signDigest({ digest: unsigned.signingDigest, privateKey: signer.privateKey });
  const envelope = {
    ...unsigned,
    signature
  };
  envelope.transactionId = flowchainTransactionId(envelope);
  const runtime = verifyFlowchainEnvelope({
    document,
    envelope,
    context: { chainId: CHAIN_ID, networkProfile: NETWORK_PROFILE, expectedNonce: nonce }
  });
  return {
    name,
    document,
    envelope,
    expected: {
      objectId: localAlphaObjectId(document),
      payloadHash: envelope.payloadHash,
      envelopeId: envelope.envelopeId,
      signingDigest: envelope.signingDigest,
      transactionId: envelope.transactionId
    },
    runtime: {
      ok: runtime.ok,
      signerAddress: runtime.signerAddress,
      signerAccountId: runtime.signerAccountId,
      payloadHash: runtime.payloadHash,
      transactionId: runtime.transactionId,
      nonce: runtime.nonce,
      chainId: runtime.chainId,
      networkProfile: runtime.networkProfile
    }
  };
}

function buildHashHelperVectors({
  positives,
  accounts,
  assets,
  poolId,
  bridgeSourceEvent,
  bridgeObservationId,
  canonicalBridgeCreditId
}) {
  const txRoot = flowchainTxRoot(positives.map((entry) => entry.envelope.transactionId));
  const receiptRoot = flowchainReceiptRoot(positives.map((entry) => entry.expected.payloadHash));
  const eventRoot = flowchainEventRoot([bridgeObservationId, canonicalBridgeCreditId]);
  const accountStateRoot = flowchainAccountStateRoot(Object.values(accounts).map((entry) => entry.publicMetadata));
  const tokenStateRoot = flowchainTokenStateRoot([assets.native, assets.token]);
  const dexStateRoot = flowchainDexStateRoot([{ poolId, baseAssetId: assets.native, quoteAssetId: assets.token }]);
  const blockHash = flowchainBlockHash({
    chainId: CHAIN_ID,
    networkProfile: NETWORK_PROFILE,
    blockNumber: "9",
    parentHash: keccakUtf8("block:8"),
    txRoot,
    receiptRoot,
    eventRoot,
    accountStateRoot,
    tokenStateRoot,
    dexStateRoot,
    timestampUnixMs: ISSUED_AT_UNIX_MS
  });
  const withdrawalIntentInput = {
    localChainId: CHAIN_ID,
    accountId: accounts.user.accountId,
    assetId: assets.token,
    amount: "10000000",
    nonce: "10",
    destination: {
      chainId: BASE_8453_CHAIN_ID,
      recipient: "0x4444444444444444444444444444444444444444"
    }
  };
  const finalityInput = {
    chainId: CHAIN_ID,
    blockNumber: "9",
    blockHash,
    stateRoot: accountStateRoot,
    validatorSetRoot: canonicalJsonHash(Object.values(accounts).map((entry) => entry.accountId)),
    round: "1",
    voteRoot: flowchainReceiptRoot([accounts.validator.accountId, blockHash])
  };
  return {
    transactionId: positives[0].envelope.transactionId,
    blockHash,
    txRoot,
    receiptRoot,
    eventRoot,
    accountStateRoot,
    tokenStateRoot,
    dexStateRoot,
    bridgeObservationId,
    bridgeCreditId: canonicalBridgeCreditId,
    withdrawalIntentId: flowchainWithdrawalIntentId(withdrawalIntentInput),
    finalityReceiptId: flowchainFinalityReceiptId(finalityInput),
    replayKeys: {
      accountNonce: accountNonceReplayKey({
        chainId: CHAIN_ID,
        networkProfile: NETWORK_PROFILE,
        accountId: accounts.user.accountId,
        nonce: "1"
      }),
      roleScopedNonce: roleScopedNonceReplayKey({
        chainId: CHAIN_ID,
        networkProfile: NETWORK_PROFILE,
        accountId: accounts.validator.accountId,
        signerRole: "validator",
        nonce: "11"
      }),
      bridgeSourceEvent: bridgeSourceEventReplayKey(bridgeSourceEvent),
      withdrawalIntent: withdrawalIntentReplayKey(withdrawalIntentInput),
      finalityVote: finalityVoteReplayKey({
        chainId: CHAIN_ID,
        validatorAccountId: accounts.validator.accountId,
        blockHash,
        round: "1",
        voteType: "precommit"
      })
    }
  };
}

function buildNegativeVectors({ positives, accounts, bridgeSourceEvent }) {
  const byName = new Map(positives.map((entry) => [entry.name, entry]));
  const specs = [
    {
      name: "wrong-chain-id",
      base: "wallet-transfer",
      context: { chainId: "31338" },
      primaryFailureCode: "wrong-chain-id"
    },
    {
      name: "wrong-network-profile",
      base: "wallet-transfer",
      context: { networkProfile: "private-lan" },
      primaryFailureCode: "wrong-network-profile"
    },
    {
      name: "wrong-domain",
      base: "wallet-transfer",
      envelope: { domain: "flowchain.production-l1.v0.transaction-envelope:profile:private-lan:chain:31337" },
      primaryFailureCode: "wrong-domain"
    },
    {
      name: "wrong-signer",
      base: "wallet-transfer",
      envelope: { signerId: accounts.recipient.accountId },
      primaryFailureCode: "wrong-signer"
    },
    {
      name: "wrong-signer-role",
      base: "bridge-credit-authority",
      envelope: { signerRole: "user", signerRoleCode: 10 },
      primaryFailureCode: "wrong-signer"
    },
    {
      name: "stale-nonce",
      base: "wallet-transfer",
      context: { minimumNonce: "2" },
      primaryFailureCode: "stale-nonce"
    },
    {
      name: "duplicate-nonce",
      base: "wallet-transfer",
      contextFactory(entry) {
        return { seenNonces: new Set([`${entry.envelope.chainId}:${entry.envelope.networkProfile}:${entry.envelope.signerId}:${entry.envelope.signerRole}:${entry.envelope.nonce}`]) };
      },
      primaryFailureCode: "duplicate-nonce"
    },
    {
      name: "duplicate-tx-id",
      base: "wallet-transfer",
      contextFactory(entry) {
        return { seenTransactionIds: new Set([entry.envelope.transactionId]) };
      },
      primaryFailureCode: "duplicate-tx-id"
    },
    {
      name: "expired-tx",
      base: "wallet-transfer",
      context: { nowUnixMs: "1778709600000" },
      primaryFailureCode: "expired-tx"
    },
    {
      name: "mutated-payload",
      base: "swap",
      document: { amountIn: "200000" },
      primaryFailureCode: "bad-payload-hash"
    },
    {
      name: "malformed-public-key",
      base: "wallet-transfer",
      envelope: { publicKey: "0x1234" },
      primaryFailureCode: "malformed-public-key"
    },
    {
      name: "malformed-signature",
      base: "wallet-transfer",
      envelope: { signature: "0x1234" },
      primaryFailureCode: "malformed-signature"
    },
    {
      name: "malformed-root",
      base: "validator-finality",
      document: { challengeRoot: "0x1234" },
      primaryFailureCode: "malformed-root"
    },
    {
      name: "duplicate-bridge-source-event",
      base: "bridge-credit-authority",
      contextFactory() {
        return {
          bridgeSourceEvent,
          seenBridgeSourceEvents: new Set([bridgeSourceEventReplayKey(bridgeSourceEvent)])
        };
      },
      primaryFailureCode: "duplicate-bridge-source-event"
    }
  ];
  return specs.map((spec) => {
    const base = byName.get(spec.base);
    const document = { ...base.document, ...(spec.document ?? {}) };
    const envelope = { ...base.envelope, ...(spec.envelope ?? {}) };
    const context = {
      chainId: CHAIN_ID,
      networkProfile: NETWORK_PROFILE,
      expectedNonce: envelope.nonce,
      ...(spec.context ?? {}),
      ...(spec.contextFactory?.(base) ?? {})
    };
    const result = verifyFlowchainEnvelope({ document, envelope, context });
    return {
      name: `production-l1.${spec.name}`,
      base: spec.base,
      mutation: {
        document: spec.document,
        envelope: spec.envelope,
        context: spec.context,
        contextKind: spec.contextFactory ? spec.name : undefined
      },
      primaryFailureCode: spec.primaryFailureCode,
      expectFailureCodes: result.failureCodes.sort()
    };
  });
}

function productTransferDocument(input) {
  return { schema: "flowchain.product_transfer.v0", transferId: productTransferId(input), ...input };
}

function productTokenLaunchDocument(input) {
  return { schema: "flowchain.product_token_launch.v0", tokenLaunchId: productTokenLaunchId(input), ...input };
}

function productPoolCreateDocument(input) {
  return { schema: "flowchain.product_pool_create.v0", poolCreateId: productPoolCreateId(input), ...input };
}

function productAddLiquidityDocument(input) {
  return { schema: "flowchain.product_add_liquidity.v0", addLiquidityId: productAddLiquidityId(input), ...input };
}

function productRemoveLiquidityDocument(input) {
  return { schema: "flowchain.product_remove_liquidity.v0", removeLiquidityId: productRemoveLiquidityId(input), ...input };
}

function productSwapDocument(input) {
  return { schema: "flowchain.product_swap.v0", swapId: productSwapId(input), ...input };
}

function localBalanceRecordDocument(input) {
  return { schema: "flowchain.local_balance_record.v0", balanceRecordId: localBalanceRecordId(input), ...input };
}

function bridgeCreditDocument(input) {
  const creditId = bridgeCreditId({ ...input, status: input.statusCode });
  return { schema: "flowchain.bridge_credit.v0", creditId, ...input };
}

function bridgeWithdrawalIntentDocument(input) {
  return { schema: "flowmemory.bridge_withdrawal_intent.v0", withdrawalIntentId: bridgeWithdrawalIntentId(input), ...input };
}

function finalityReceiptDocument(input) {
  const idInput = {
    ...input,
    finalityState: input.finalityStateCode
  };
  return { schema: "flowchain.finality_receipt.v0", finalityReceiptId: finalityReceiptId(idInput), ...input };
}

function deterministicTestPrivateKey(index) {
  const bytes = new Uint8Array(32);
  bytes[31] = index;
  return bytesToHex(bytes);
}
