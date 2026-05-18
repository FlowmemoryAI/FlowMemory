import { DOMAIN_STRINGS, TYPE_STRINGS } from "./constants.js";
import { canonicalJsonHash, keccakUtf8, typedHash } from "./hashes.js";
import { hexToBytes } from "./encoding.js";
import { merkleRoot } from "./merkle.js";

export const FLOWCHAIN_NETWORK_PROFILES = Object.freeze({
  localChain: "local-chain",
  privateLan: "private-lan",
  base8453PilotBridge: "base-8453-pilot-bridge"
});

export const FLOWCHAIN_DOMAIN_SEPARATORS = Object.freeze({
  localChain: DOMAIN_STRINGS.productionLocalChain,
  privateLan: DOMAIN_STRINGS.productionPrivateLan,
  base8453PilotBridge: DOMAIN_STRINGS.productionBase8453PilotBridge,
  objectLifecycle: DOMAIN_STRINGS.productionObjectLifecycle,
  tokenDex: DOMAIN_STRINGS.productionTokenDex,
  validatorFinality: DOMAIN_STRINGS.productionValidatorFinality
});

export function flowchainNetworkProfileHash(networkProfile) {
  assertNetworkProfile(networkProfile);
  return keccakUtf8(networkProfile);
}

export function flowchainProductionDomain({ chainId, networkProfile }) {
  assertNetworkProfile(networkProfile);
  return `${DOMAIN_STRINGS.productionL1TransactionEnvelope}:profile:${networkProfile}:chain:${chainId}`;
}

export function flowchainProductionDomainSeparator({ chainId, networkProfile }) {
  return canonicalJsonHash({
    domain: DOMAIN_STRINGS.productionL1TransactionEnvelope,
    chainId: String(chainId),
    networkProfile
  });
}

export function flowchainTransactionId(envelope) {
  const networkProfile = envelope.networkProfile ?? FLOWCHAIN_NETWORK_PROFILES.localChain;
  return typedHash(TYPE_STRINGS.flowchainTransactionIdV0, [
    ["uint256", envelope.chainId],
    ["bytes32", flowchainNetworkProfileHash(networkProfile)],
    ["bytes32", envelope.envelopeId],
    ["bytes32", envelope.payloadHash],
    ["bytes32", canonicalJsonHash({ signature: envelope.signature ?? "" })]
  ]);
}

export function flowchainTxRoot(transactions) {
  return rootFromItems("flowchain.production-l1.v0.tx-root", transactions);
}

export function flowchainReceiptRoot(receipts) {
  return rootFromItems("flowchain.production-l1.v0.receipt-root", receipts);
}

export function flowchainEventRoot(events) {
  return rootFromItems("flowchain.production-l1.v0.event-root", events);
}

export function flowchainAccountStateRoot(accounts) {
  return rootFromItems("flowchain.production-l1.v0.account-state-root", accounts);
}

export function flowchainTokenStateRoot(tokens) {
  return rootFromItems("flowchain.production-l1.v0.token-state-root", tokens);
}

export function flowchainDexStateRoot(pools) {
  return rootFromItems("flowchain.production-l1.v0.dex-state-root", pools);
}

export function flowchainBlockHash(input) {
  return canonicalJsonHash({
    domain: "flowchain.production-l1.v0.block-hash",
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

export function flowchainBridgeObservationId({
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
  return typedHash(TYPE_STRINGS.flowchainBridgeObservationV0, [
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

export function flowchainBridgeCreditId({ observationId, localRecipient, localChainId, creditAmount }) {
  return typedHash(TYPE_STRINGS.flowchainBridgeCreditV1, [
    ["bytes32", observationId],
    ["bytes32", localRecipient],
    ["uint256", localChainId],
    ["uint256", creditAmount]
  ]);
}

export function flowchainWithdrawalIntentId({ localChainId, accountId, assetId, amount, nonce, destination }) {
  return typedHash(TYPE_STRINGS.flowchainWithdrawalIntentV1, [
    ["uint256", localChainId],
    ["bytes32", accountId],
    ["bytes32", assetId],
    ["uint256", amount],
    ["uint64", nonce],
    ["bytes32", canonicalJsonHash(destination)]
  ]);
}

export function flowchainFinalityReceiptId({
  chainId,
  blockNumber,
  blockHash,
  stateRoot,
  validatorSetRoot,
  round,
  voteRoot
}) {
  return typedHash(TYPE_STRINGS.flowchainFinalityReceiptV1, [
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
    domain: "flowchain.production-l1.v0.account-nonce-replay-key",
    chainId: String(chainId),
    networkProfile,
    accountId,
    nonce: String(nonce)
  });
}

export function roleScopedNonceReplayKey({ chainId, networkProfile, accountId, signerRole, nonce }) {
  return canonicalJsonHash({
    domain: "flowchain.production-l1.v0.role-scoped-nonce-replay-key",
    chainId: String(chainId),
    networkProfile,
    accountId,
    signerRole,
    nonce: String(nonce)
  });
}

export function bridgeSourceEventReplayKey(input) {
  return flowchainBridgeObservationId(input);
}

export function withdrawalIntentReplayKey(input) {
  return flowchainWithdrawalIntentId(input);
}

export function finalityVoteReplayKey({ chainId, validatorAccountId, blockHash, round, voteType }) {
  return canonicalJsonHash({
    domain: "flowchain.production-l1.v0.finality-vote-replay-key",
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
  if (!Object.values(FLOWCHAIN_NETWORK_PROFILES).includes(networkProfile)) {
    throw new Error(`unsupported FlowChain network profile: ${networkProfile}`);
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
