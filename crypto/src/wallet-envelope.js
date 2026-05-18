import { ZERO_BYTES32 } from "./constants.js";
import { canonicalJsonHash, keccakUtf8 } from "./hashes.js";
import { localTransactionReplayKey, validateLocalTransactionEnvelope } from "./transactions.js";
import { signLocalTransactionWithVault } from "./wallet.js";

export const WALLET_SIGNED_ENVELOPE_SCHEMA = "flowchain.wallet_signed_envelope.v0";
export const WALLET_ENVELOPE_VERIFICATION_SCHEMA = "flowchain.wallet_envelope_verification.v0";

export async function signWalletDocumentWithVault({
  vault,
  password,
  signerKeyId,
  document,
  chainId,
  nonce,
  issuedAtUnixMs = Date.now().toString(),
  fee = null,
  expiresAtUnixMs = null
}) {
  const localEnvelope = await signLocalTransactionWithVault({
    vault,
    password,
    signerKeyId,
    document,
    chainId,
    nonce,
    issuedAtUnixMs
  });
  const signerAddress = localEnvelope.signerId;
  const envelope = {
    schema: WALLET_SIGNED_ENVELOPE_SCHEMA,
    version: "0",
    txId: localEnvelope.envelopeId,
    chainId: String(localEnvelope.chainId),
    payloadType: document.schema,
    payload: document,
    tx: document,
    signerAddress,
    signer: {
      address: signerAddress,
      signerId: localEnvelope.signerId,
      signerKeyId: localEnvelope.signerKeyId,
      signerRole: localEnvelope.signerRole,
      publicKey: localEnvelope.publicKey,
      publicKeyReference: localEnvelope.signerKeyId,
      keyScheme: "secp256k1"
    },
    nonce: String(localEnvelope.nonce),
    fee: fee ?? {
      supported: false,
      amount: "0",
      assetId: ZERO_BYTES32
    },
    validity: {
      issuedAtUnixMs: String(localEnvelope.issuedAtUnixMs),
      expiresAtUnixMs,
      expirationSupported: expiresAtUnixMs !== null
    },
    signature: localEnvelope.signature,
    localEnvelope
  };
  envelope.verification = verifyWalletSignedEnvelope({ envelope, context: { chainId, expectedNonce: nonce } });
  return envelope;
}

export function verifyWalletSignedEnvelope({ envelope, context = {} }) {
  const errors = new Set();
  if (!envelope || typeof envelope !== "object") {
    return verificationOutput({ errors: ["missing-envelope"] });
  }

  if (envelope.schema === "flowchain.local_transaction_envelope.v0") {
    return verifyLocalOnlyEnvelope({ envelope, context });
  }

  if (envelope.schema !== WALLET_SIGNED_ENVELOPE_SCHEMA) {
    errors.add("wrong-envelope-schema");
  }

  const document = envelope.payload ?? envelope.tx;
  const localEnvelope = envelope.localEnvelope;
  if (!document || typeof document !== "object" || Array.isArray(document)) {
    errors.add("missing-payload");
  }
  if (!localEnvelope || typeof localEnvelope !== "object" || Array.isArray(localEnvelope)) {
    errors.add("missing-local-envelope");
  }

  let base = { valid: false, errors: ["missing-local-envelope"] };
  if (document && localEnvelope) {
    base = validateLocalTransactionEnvelope({
      document,
      envelope: localEnvelope,
      context: {
        chainId: context.chainId,
        expectedNonce: context.expectedNonce,
        expectedSignerId: context.expectedSignerId,
        seenNonces: context.seenNonces
      }
    });
    for (const error of base.errors) {
      errors.add(error);
    }
  }

  if (context.expectedPayloadType && envelope.payloadType !== context.expectedPayloadType) {
    errors.add("wrong-payload-type");
  }
  if (context.chainId !== undefined && String(envelope.chainId) !== String(context.chainId)) {
    errors.add("wrong-chain-id");
  }
  if (context.expectedNonce !== undefined && String(envelope.nonce) !== String(context.expectedNonce)) {
    errors.add("wrong-nonce");
  }
  if (context.expectedSignerAddress && envelope.signerAddress !== context.expectedSignerAddress) {
    errors.add("wrong-signer");
  }
  if (document && envelope.payloadType !== document.schema) {
    errors.add("wrong-payload-type");
  }
  if (localEnvelope) {
    if (envelope.txId !== localEnvelope.envelopeId || envelope.signature !== localEnvelope.signature) {
      errors.add("bad-envelope-id");
    }
    if (
      envelope.chainId !== String(localEnvelope.chainId) ||
      envelope.nonce !== String(localEnvelope.nonce) ||
      envelope.signerAddress !== localEnvelope.signerId
    ) {
      errors.add("envelope-metadata-mismatch");
    }
    if (envelope.signer?.publicKey !== localEnvelope.publicKey || envelope.signer?.signerKeyId !== localEnvelope.signerKeyId) {
      errors.add("signer-metadata-mismatch");
    }
  }
  if (envelope.signer?.publicKey && !isPublicKey(envelope.signer.publicKey)) {
    errors.add("malformed-public-key");
  }

  const signerDerivedAddress = signerAddressFromPublicKey(envelope.signer?.publicKey ?? localEnvelope?.publicKey);
  if (signerDerivedAddress && localEnvelope?.signerId && signerDerivedAddress !== localEnvelope.signerId) {
    errors.add("public-key-mismatch");
  }

  return verificationOutput({
    errors: [...errors],
    signatureValid: base.valid && !base.errors.includes("bad-signature") && !base.errors.includes("missing-signer"),
    chainIdMatch: !(errors.has("wrong-chain-id") || errors.has("wrong-domain")),
    signerDerivedAddress,
    payloadHash: document ? canonicalJsonHash(document) : null,
    transactionId: envelope.txId ?? localEnvelope?.envelopeId ?? null,
    replayKey: localEnvelope ? localTransactionReplayKey(localEnvelope) : null
  });
}

function verifyLocalOnlyEnvelope({ envelope, context }) {
  const errors = [];
  if (!context.document) {
    errors.push("missing-payload");
    return verificationOutput({ errors, transactionId: envelope.envelopeId ?? null });
  }
  const base = validateLocalTransactionEnvelope({
    document: context.document,
    envelope,
    context
  });
  return verificationOutput({
    errors: base.errors,
    signatureValid: base.valid && !base.errors.includes("bad-signature") && !base.errors.includes("missing-signer"),
    chainIdMatch: !base.errors.includes("wrong-chain-id") && !base.errors.includes("wrong-domain"),
    signerDerivedAddress: signerAddressFromPublicKey(envelope.publicKey),
    payloadHash: canonicalJsonHash(context.document),
    transactionId: envelope.envelopeId ?? null,
    replayKey: localTransactionReplayKey(envelope)
  });
}

function verificationOutput({
  errors,
  signatureValid = false,
  chainIdMatch = false,
  signerDerivedAddress = null,
  payloadHash = null,
  transactionId = null,
  replayKey = null
}) {
  const uniqueErrors = [...new Set(errors)];
  return {
    schema: WALLET_ENVELOPE_VERIFICATION_SCHEMA,
    valid: uniqueErrors.length === 0,
    signatureValid,
    chainIdMatch,
    signerDerivedAddress,
    payloadHash,
    transactionId,
    replayKey,
    rejectionReason: uniqueErrors.length === 0 ? null : uniqueErrors.join(","),
    errors: uniqueErrors
  };
}

function signerAddressFromPublicKey(publicKey) {
  if (!isPublicKey(publicKey)) {
    return null;
  }
  return keccakUtf8(`flowchain.local-alpha.signer:${publicKey}`);
}

function isPublicKey(value) {
  return typeof value === "string" && /^0x([0-9a-fA-F]{66}|[0-9a-fA-F]{130})$/.test(value);
}
