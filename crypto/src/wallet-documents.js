import { ZERO_BYTES32 } from "./constants.js";
import { keccakUtf8 } from "./hashes.js";
import {
  bridgeWithdrawalIntentId,
  finalityReceiptId,
  productAddLiquidityId,
  productPoolCreateId,
  productRemoveLiquidityId,
  productSwapId,
  productTokenLaunchId,
  productTransferId
} from "./objects.js";

export const LOCAL_TEST_UNIT_ASSET_ID = keccakUtf8("flowmemory.asset.local-test-unit.v0");

export function buildProductTransferDocument({
  fromAccountId,
  toAccountId,
  assetId = LOCAL_TEST_UNIT_ASSET_ID,
  amount,
  accountNonce,
  deadlineBlock = "0",
  memo,
  memoHash
}) {
  const document = {
    schema: "flowmemory.product_transfer.v0",
    transferId: ZERO_BYTES32,
    fromAccountId: requireHex32(fromAccountId, "fromAccountId"),
    toAccountId: requireHex32(toAccountId, "toAccountId"),
    assetId: requireHex32(assetId, "assetId"),
    amount: requirePositiveUintString(amount, "amount"),
    accountNonce: requireUintString(accountNonce, "accountNonce"),
    deadlineBlock: requireUintString(deadlineBlock, "deadlineBlock"),
    memoHash: memoHash ? requireHex32(memoHash, "memoHash") : keccakUtf8(memo ?? "")
  };
  document.transferId = productTransferId(document);
  return document;
}

export function buildProductTokenLaunchDocument({
  issuerAccountId,
  symbol,
  name,
  supply,
  ownerAccountId,
  recipientAccountId = ownerAccountId,
  decimals = 18,
  accountNonce,
  tokenId,
  metadataHash,
  launchPolicyHash
}) {
  const normalizedSymbol = normalizeTokenSymbol(symbol);
  const normalizedName = requireNonEmptyString(name, "name");
  const document = {
    schema: "flowmemory.product_token_launch.v0",
    tokenLaunchId: ZERO_BYTES32,
    issuerAccountId: requireHex32(issuerAccountId, "issuerAccountId"),
    tokenId: tokenId ? requireHex32(tokenId, "tokenId") : keccakUtf8(`flowmemory.product-token:${normalizedSymbol}:${normalizedName}`),
    symbolHash: keccakUtf8(normalizedSymbol),
    nameHash: keccakUtf8(normalizedName),
    metadataHash: metadataHash ? requireHex32(metadataHash, "metadataHash") : keccakUtf8(`metadata:${normalizedSymbol}:${normalizedName}`),
    decimals: normalizeSmallInteger(decimals, "decimals", 0, 18),
    initialSupply: requirePositiveUintString(supply, "supply"),
    recipientAccountId: requireHex32(recipientAccountId, "recipientAccountId"),
    accountNonce: requireUintString(accountNonce, "accountNonce"),
    launchPolicyHash: launchPolicyHash ? requireHex32(launchPolicyHash, "launchPolicyHash") : keccakUtf8("flowmemory.product-token.launch-policy.local")
  };
  document.tokenLaunchId = productTokenLaunchId(document);
  return document;
}

export function buildProductPoolCreateDocument({
  creatorAccountId,
  baseAssetId,
  quoteAssetId,
  baseReserve,
  quoteReserve,
  poolId,
  feeBps = 30,
  tickSpacing = 1,
  metadataHash,
  accountNonce
}) {
  const base = requireHex32(baseAssetId, "baseAssetId");
  const quote = requireHex32(quoteAssetId, "quoteAssetId");
  if (base === quote) {
    throw new Error("pool token pair must contain two different assets");
  }
  const reserveHash = keccakUtf8(JSON.stringify({
    baseReserve: requirePositiveUintString(baseReserve, "baseReserve"),
    quoteReserve: requirePositiveUintString(quoteReserve, "quoteReserve")
  }));
  const document = {
    schema: "flowmemory.product_pool_create.v0",
    poolCreateId: ZERO_BYTES32,
    creatorAccountId: requireHex32(creatorAccountId, "creatorAccountId"),
    poolId: poolId ? requireHex32(poolId, "poolId") : keccakUtf8(`flowmemory.pool:${base}:${quote}:${feeBps}:${tickSpacing}`),
    baseAssetId: base,
    quoteAssetId: quote,
    feeBps: normalizeSmallInteger(feeBps, "feeBps", 0, 10000),
    tickSpacing: normalizeSmallInteger(tickSpacing, "tickSpacing", 1, 1000000),
    metadataHash: metadataHash ? requireHex32(metadataHash, "metadataHash") : reserveHash,
    accountNonce: requireUintString(accountNonce, "accountNonce")
  };
  document.poolCreateId = productPoolCreateId(document);
  return document;
}

export function buildProductAddLiquidityDocument({
  providerAccountId,
  poolId,
  baseAmount,
  quoteAmount,
  minLiquidityTokens,
  deadlineBlock,
  accountNonce
}) {
  const document = {
    schema: "flowmemory.product_add_liquidity.v0",
    addLiquidityId: ZERO_BYTES32,
    providerAccountId: requireHex32(providerAccountId, "providerAccountId"),
    poolId: requireHex32(poolId, "poolId"),
    baseAmount: requirePositiveUintString(baseAmount, "baseAmount"),
    quoteAmount: requirePositiveUintString(quoteAmount, "quoteAmount"),
    minLiquidityTokens: requireUintString(minLiquidityTokens, "minLiquidityTokens"),
    deadlineBlock: requireUintString(deadlineBlock, "deadlineBlock"),
    accountNonce: requireUintString(accountNonce, "accountNonce")
  };
  document.addLiquidityId = productAddLiquidityId(document);
  return document;
}

export function buildProductRemoveLiquidityDocument({
  providerAccountId,
  poolId,
  liquidityTokens,
  minBaseAmount,
  minQuoteAmount,
  deadlineBlock,
  accountNonce
}) {
  const document = {
    schema: "flowmemory.product_remove_liquidity.v0",
    removeLiquidityId: ZERO_BYTES32,
    providerAccountId: requireHex32(providerAccountId, "providerAccountId"),
    poolId: requireHex32(poolId, "poolId"),
    liquidityTokens: requirePositiveUintString(liquidityTokens, "liquidityTokens"),
    minBaseAmount: requireUintString(minBaseAmount, "minBaseAmount"),
    minQuoteAmount: requireUintString(minQuoteAmount, "minQuoteAmount"),
    deadlineBlock: requireUintString(deadlineBlock, "deadlineBlock"),
    accountNonce: requireUintString(accountNonce, "accountNonce")
  };
  document.removeLiquidityId = productRemoveLiquidityId(document);
  return document;
}

export function buildProductSwapDocument({
  traderAccountId,
  poolId,
  assetInId,
  assetOutId,
  amountIn,
  minAmountOut,
  deadlineBlock,
  accountNonce
}) {
  const assetIn = requireHex32(assetInId, "assetInId");
  const assetOut = requireHex32(assetOutId, "assetOutId");
  if (assetIn === assetOut) {
    throw new Error("swap input and output assets must differ");
  }
  const document = {
    schema: "flowmemory.product_swap.v0",
    swapId: ZERO_BYTES32,
    traderAccountId: requireHex32(traderAccountId, "traderAccountId"),
    poolId: requireHex32(poolId, "poolId"),
    assetInId: assetIn,
    assetOutId: assetOut,
    amountIn: requirePositiveUintString(amountIn, "amountIn"),
    minAmountOut: requireUintString(minAmountOut, "minAmountOut"),
    deadlineBlock: requireUintString(deadlineBlock, "deadlineBlock"),
    accountNonce: requireUintString(accountNonce, "accountNonce")
  };
  document.swapId = productSwapId(document);
  return document;
}

export function buildBridgeWithdrawalIntentDocument({
  creditId,
  depositId,
  sourceChainId,
  destinationChainId = 8453,
  token,
  amount,
  flowmemoryAccount,
  baseRecipient,
  requestedAt,
  status = "requested",
  testMode = true,
  broadcast = false,
  releasePolicy = "test_record_only",
  productionReady = false
}) {
  const document = {
    schema: "flowmemory.bridge_withdrawal_intent.v0",
    withdrawalIntentId: ZERO_BYTES32,
    creditId: requireHex32(creditId, "creditId"),
    depositId: requireHex32(depositId, "depositId"),
    sourceChainId: normalizeChainIdNumber(sourceChainId, "sourceChainId"),
    destinationChainId: normalizeChainIdNumber(destinationChainId, "destinationChainId"),
    token: requireEthAddress(token, "token"),
    amount: requirePositiveUintString(amount, "amount"),
    flowmemoryAccount: requireHex32(flowmemoryAccount, "flowmemoryAccount"),
    baseRecipient: requireEthAddress(baseRecipient, "baseRecipient"),
    status,
    requestedAt: requestedAt ?? new Date(0).toISOString(),
    testMode,
    broadcast,
    releasePolicy,
    productionReady
  };
  document.withdrawalIntentId = bridgeWithdrawalIntentId(document);
  return document;
}

export function buildFinalityActionDocument({
  receiptId,
  reportId,
  challengeRoot = ZERO_BYTES32,
  finalityState = 4,
  finalizedAtUnixMs,
  finalizedBlockNumber,
  finalizedBlockHash,
  policyHash
}) {
  const finalityStateCode = normalizeSmallInteger(finalityState, "finalityState", 1, 255);
  const document = {
    schema: "flowmemory.finality_receipt.v0",
    finalityReceiptId: ZERO_BYTES32,
    receiptId: requireHex32(receiptId, "receiptId"),
    reportId: requireHex32(reportId, "reportId"),
    challengeRoot: requireHex32(challengeRoot, "challengeRoot"),
    finalityState: finalityStateName(finalityStateCode),
    finalityStateCode,
    finalizedAtUnixMs: requireUintString(finalizedAtUnixMs, "finalizedAtUnixMs"),
    finalizedBlockNumber: requireUintString(finalizedBlockNumber, "finalizedBlockNumber"),
    finalizedBlockHash: requireHex32(finalizedBlockHash, "finalizedBlockHash"),
    policyHash: requireHex32(policyHash, "policyHash")
  };
  document.finalityReceiptId = finalityReceiptId({
    receiptId: document.receiptId,
    reportId: document.reportId,
    challengeRoot: document.challengeRoot,
    finalityState: document.finalityStateCode,
    finalizedAtUnixMs: document.finalizedAtUnixMs,
    finalizedBlockNumber: document.finalizedBlockNumber,
    finalizedBlockHash: document.finalizedBlockHash,
    policyHash: document.policyHash
  });
  return document;
}

export function requireHex32(value, field) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]{64}$/.test(value)) {
    throw new Error(`${field} must be a 32-byte hex value`);
  }
  return value.toLowerCase();
}

export function requireEthAddress(value, field) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new Error(`${field} must be a 20-byte hex address`);
  }
  return value.toLowerCase();
}

export function requireUintString(value, field) {
  const normalized = String(value);
  if (!/^[0-9]+$/.test(normalized)) {
    throw new Error(`${field} must be an unsigned integer string`);
  }
  return normalized;
}

export function requirePositiveUintString(value, field) {
  const normalized = requireUintString(value, field);
  if (BigInt(normalized) <= 0n) {
    throw new Error(`${field} must be positive`);
  }
  return normalized;
}

function normalizeTokenSymbol(value) {
  const symbol = requireNonEmptyString(value, "symbol").toUpperCase();
  if (!/^[A-Z][A-Z0-9]{1,15}$/.test(symbol)) {
    throw new Error("token symbol must be 2-16 uppercase alphanumeric characters and start with a letter");
  }
  return symbol;
}

function requireNonEmptyString(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${field} is required`);
  }
  return value.trim();
}

function normalizeSmallInteger(value, field, min, max) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new Error(`${field} must be an integer between ${min} and ${max}`);
  }
  return parsed;
}

function normalizeChainIdNumber(value, field) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(parsed) || ![31337, 84532, 8453].includes(parsed)) {
    throw new Error(`${field} must be one of 31337, 84532, or 8453`);
  }
  return parsed;
}

function finalityStateName(code) {
  const names = {
    1: "provisional",
    2: "challengeable",
    3: "challenged",
    4: "accepted",
    5: "rejected",
    6: "finalized",
    7: "superseded",
    8: "reorged"
  };
  if (!names[code]) {
    throw new Error("unsupported finality state code");
  }
  return names[code];
}
