import { DOMAIN_STRINGS, TYPE_STRINGS } from "./constants.js";
import { canonicalJsonHash, keccakUtf8, typedHash } from "./hashes.js";
import { hexToBytes } from "./encoding.js";
import { merkleRoot } from "./merkle.js";

export const FLOWMEMORY_NETWORK_PROFILES = Object.freeze({
  localChain: "local-chain",
  privateLan: "private-lan",
  base8453PilotBridge: "base-8453-pilot-bridge"
});

export const FLOWMEMORY_DOMAIN_SEPARATORS = Object.freeze({
  localChain: DOMAIN_STRINGS.productionLocalChain,
  privateLan: DOMAIN_STRINGS.productionPrivateLan,
  base8453PilotBridge: DOMAIN_STRINGS.productionBase8453PilotBridge,
  objectLifecycle: DOMAIN_STRINGS.productionObjectLifecycle,
  tokenDex: DOMAIN_STRINGS.productionTokenDex,
  validatorFinality: DOMAIN_STRINGS.productionValidatorFinality
});

export function flowmemoryNetworkProfileHash(networkProfile) {
  assertNetworkProfile(networkProfile);
  return keccakUtf8(networkProfile);
}

export function flowmemoryProductionDomain({ chainId, networkProfile }) {
  assertNetworkProfile(networkProfile);
  return `${DOMAIN_STRINGS.productionNetworkTransactionEnvelope}:profile:${networkProfile}:chain:${chainId}`;
}

export function flowmemoryProductionDomainSeparator({ chainId, networkProfile }) {
  return canonicalJsonHash({
    domain: DOMAIN_STRINGS.productionNetworkTransactionEnvelope,
    chainId: String(chainId),
    networkProfile
  });
}

export function flowmemoryTransactionId(envelope) {
  const networkProfile = envelope.networkProfile ?? FLOWMEMORY_NETWORK_PROFILES.localChain;
  return typedHash(TYPE_STRINGS.flowmemoryTransactionIdV0, [
    ["uint256", envelope.chainId],
    ["bytes32", flowmemoryNetworkProfileHash(networkProfile)],
    ["bytes32", envelope.envelopeId],
    ["bytes32", envelope.payloadHash],
    ["bytes32", canonicalJsonHash({ signature: envelope.signature ?? "" })]
  ]);
}

export function flowmemoryTxRoot(transactions) {
  return rootFromItems("flowmemory.production-network.v0.tx-root", transactions);
}

export function flowmemoryReceiptRoot(receipts) {
  return rootFromItems("flowmemory.production-network.v0.receipt-root", receipts);
}

export function flowmemoryEventRoot(events) {
  return rootFromItems("flowmemory.production-network.v0.event-root", events);
}

export function flowmemoryAccountStateRoot(accounts) {
  return rootFromItems("flowmemory.production-network.v0.account-state-root", accounts);
}

export function flowmemoryTokenStateRoot(tokens) {
  return rootFromItems("flowmemory.production-network.v0.token-state-root", tokens);
}

export function flowmemoryDexStateRoot(pools) {
  return rootFromItems("flowmemory.production-network.v0.dex-state-root", pools);
}

export function flowmemoryBlockHash(input) {
  return canonicalJsonHash({
    domain: "flowmemory.production-network.v0.block-hash",
    chainId: String(input.chainId),
    networkProfile: input.networkProfile,
    blockNumber: String(input.blockNumber),
    parentHash: input.parentHash,
    txRoot: input.txRoot,
    receiptRoot: input.receiptRoot,
    eventRoot: input.eventRoot,
    accountStateRoot: input.accountStateRoot,
    tokenStateRoot: input.tokenStateRoot,
    dexStateRoot: input.dexStateRoot,
    timestampUnixMs: String(input.timestampUnixMs)
  });
}

export function flowmemoryBridgeObservationId({
  sourceChainId,
  lockbox,
  token,
  depositor,
  recipient,
  amount,
  txHash,
  logIndex,
  blockNumber,
  eventNonce = "0"
}) {
  return typedHash(TYPE_STRINGS.flowmemoryBridgeObservationV0, [
    ["uint256", sourceChainId],
    ["address", lockbox],
    ["address", token],
    ["address", depositor],
    ["bytes32", recipient],
    ["uint256", amount],
    ["bytes32", txHash],
    ["uint32", logIndex],
    ["uint64", blockNumber],
    ["uint256", eventNonce]
  ]);
}

export function flowmemoryBridgeCreditId({ observationId, localRecipient, localChainId, creditAmount }) {
  return typedHash(TYPE_STRINGS.flowmemoryBridgeCreditV1, [
    ["bytes32", observationId],
    ["bytes32", localRecipient],
    ["uint256", localChainId],
    ["uint256", creditAmount]
  ]);
}

export function flowmemoryBridgeSourceEventReplayKey({ sourceChainId, lockbox, txHash, logIndex }) {
  return typedHash(TYPE_STRINGS.flowmemoryBridgeSourceEventReplayKeyV0, [
    ["uint256", sourceChainId],
    ["address", lockbox],
    ["bytes32", txHash],
    ["uint32", logIndex]
  ]);
}

export function flowmemoryBridgeEvidenceHash({
  sourceEventReplayKey,
  observationId,
  creditId,
  depositId,
  localChainId,
  evidencePayloadHash
}) {
  return typedHash(TYPE_STRINGS.flowmemoryBridgeEvidenceHashV0, [
    ["bytes32", sourceEventReplayKey],
    ["bytes32", observationId],
    ["bytes32", creditId],
    ["bytes32", depositId],
    ["uint256", localChainId],
    ["bytes32", evidencePayloadHash]
  ]);
}

export function flowmemoryWithdrawalIntentId({ localChainId, accountId, assetId, amount, nonce, destination }) {
  return typedHash(TYPE_STRINGS.flowmemoryWithdrawalIntentV1, [
    ["uint256", localChainId],
    ["bytes32", accountId],
    ["bytes32", assetId],
    ["uint256", amount],
    ["uint64", nonce],
    ["bytes32", canonicalJsonHash(destination)]
  ]);
}

export function flowmemoryFinalityReceiptId({
  chainId,
  blockNumber,
  blockHash,
  stateRoot,
  validatorSetRoot,
  round,
  voteRoot
}) {
  return typedHash(TYPE_STRINGS.flowmemoryFinalityReceiptV1, [
    ["uint256", chainId],
    ["uint64", blockNumber],
    ["bytes32", blockHash],
    ["bytes32", stateRoot],
    ["bytes32", validatorSetRoot],
    ["uint64", round],
    ["bytes32", voteRoot]
  ]);
}

export function accountNonceReplayKey({ chainId, networkProfile, accountId, nonce }) {
  return canonicalJsonHash({
    domain: "flowmemory.production-network.v0.account-nonce-replay-key",
    chainId: String(chainId),
    networkProfile,
    accountId,
    nonce: String(nonce)
  });
}

export function roleScopedNonceReplayKey({ chainId, networkProfile, accountId, signerRole, nonce }) {
  return canonicalJsonHash({
    domain: "flowmemory.production-network.v0.role-scoped-nonce-replay-key",
    chainId: String(chainId),
    networkProfile,
    accountId,
    signerRole,
    nonce: String(nonce)
  });
}

export function bridgeSourceEventReplayKey(input) {
  return flowmemoryBridgeSourceEventReplayKey(input);
}

export function withdrawalIntentReplayKey(input) {
  return flowmemoryWithdrawalIntentId(input);
}

export function finalityVoteReplayKey({ chainId, validatorAccountId, blockHash, round, voteType }) {
  return canonicalJsonHash({
    domain: "flowmemory.production-network.v0.finality-vote-replay-key",
    chainId: String(chainId),
    validatorAccountId,
    blockHash,
    round: String(round),
    voteType
  });
}

function rootFromItems(domain, items) {
  if (!Array.isArray(items)) {
    throw new Error("root items must be an array");
  }
  const leaves = items.map((item) => (isHex32(item) ? item.toLowerCase() : canonicalJsonHash({ domain, item })));
  return merkleRoot(leaves);
}

function assertNetworkProfile(networkProfile) {
  if (!Object.values(FLOWMEMORY_NETWORK_PROFILES).includes(networkProfile)) {
    throw new Error(`unsupported FlowMemory network profile: ${networkProfile}`);
  }
}

function isHex32(value) {
  if (typeof value !== "string") {
    return false;
  }
  try {
    hexToBytes(value, 32);
    return true;
  } catch {
    return false;
  }
}
