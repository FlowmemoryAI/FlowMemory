#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../..");
const schemasDir = resolve(repoRoot, "schemas", "flowmemory");
const fixturesDir = here;

const ZERO_HASH = `0x${"0".repeat(64)}`;
const PROTOCOL_VERSION = "flowchain.private_local_l1.protocol.v0";
const GENESIS_INPUT_SCHEMA = "flowchain.production_l1.genesis_input.v0";
const GENESIS_SCHEMA = "flowchain.production_l1.genesis.v0";
const PROFILE_SCHEMA = "flowchain.production_l1.network_profile.v0";
const ACCOUNT_SCHEMA = "flowchain.production_l1.account_public_metadata.v0";
const AUTHORITY_SCHEMA = "flowchain.production_l1.validator_authority.v0";
const PAYLOAD_SCHEMA = "flowchain.production_l1.transaction_payload.v0";
const ENVELOPE_SCHEMA = "flowchain.production_l1.transaction_envelope.v0";
const BLOCK_HEADER_SCHEMA = "flowchain.production_l1.block_header.v0";
const BLOCK_BODY_SCHEMA = "flowchain.production_l1.block_body.v0";
const RECEIPT_SCHEMA = "flowchain.production_l1.receipt.v0";
const EVENT_SCHEMA = "flowchain.production_l1.event.v0";
const STATE_ROOT_SCHEMA = "flowchain.production_l1.state_root_manifest.v0";
const BRIDGE_EVIDENCE_SCHEMA = "flowchain.production_l1.bridge_evidence.v0";
const FINALITY_SCHEMA = "flowchain.production_l1.finality_receipt.v0";
const EXPORT_SNAPSHOT_SCHEMA = "flowchain.production_l1.export_snapshot.v0";

const PROFILE_IDS = [
  "flowchain-local-private",
  "flowchain-local-multinode",
  "flowchain-base8453-pilot"
];

const PAYLOAD_TYPES = [
  "native_transfer",
  "faucet_funding",
  "bridge_credit",
  "token_launch",
  "token_mint",
  "token_transfer",
  "pool_create",
  "add_liquidity",
  "remove_liquidity",
  "swap",
  "withdrawal_intent",
  "validator_authority_config",
  "finality_vote",
  "finality_certificate",
  "agent_account_update",
  "model_passport_update",
  "work_receipt_update",
  "artifact_availability_proof_update",
  "verifier_module_update",
  "verifier_report_update",
  "memory_cell_update",
  "challenge_update",
  "finality_receipt_update"
];

const OBJECT_PAYLOAD_TYPES = [
  "agent_account_update",
  "model_passport_update",
  "work_receipt_update",
  "artifact_availability_proof_update",
  "verifier_module_update",
  "verifier_report_update",
  "memory_cell_update",
  "challenge_update",
  "finality_receipt_update"
];

const OBJECT_TYPES = [
  "AgentAccount",
  "ModelPassport",
  "WorkReceipt",
  "ArtifactAvailabilityProof",
  "VerifierModule",
  "VerifierReport",
  "MemoryCell",
  "Challenge",
  "FinalityReceipt"
];

const STATE_COMPONENTS = [
  "accounts",
  "balances",
  "tokens",
  "pools",
  "lp_positions",
  "bridge_credits",
  "withdrawals",
  "object_store",
  "finality",
  "validator_state"
];

const EVENT_TYPES = [
  "NativeTransferRecorded",
  "FaucetFundingRecorded",
  "BridgeCreditApplied",
  "TokenLaunched",
  "TokenMinted",
  "TokenTransferred",
  "PoolCreated",
  "LiquidityAdded",
  "LiquidityRemoved",
  "SwapExecuted",
  "WithdrawalIntentRecorded",
  "ValidatorAuthorityConfigured",
  "FinalityVoteRecorded",
  "FinalityCertificateRecorded",
  "ObjectLifecycleUpdated"
];

const ERROR_CODES = {
  WRONG_CHAIN: "FC_PROTO_WRONG_CHAIN_ID",
  WRONG_PROFILE: "FC_PROTO_WRONG_NETWORK_PROFILE",
  WRONG_GENESIS: "FC_PROTO_WRONG_GENESIS_HASH",
  STALE_NONCE: "FC_PROTO_STALE_NONCE",
  DUPLICATE_TX: "FC_PROTO_DUPLICATE_TX",
  MALFORMED_PAYLOAD_HASH: "FC_PROTO_MALFORMED_PAYLOAD_HASH",
  MALFORMED_TX_ID: "FC_PROTO_MALFORMED_TX_ID",
  MALFORMED_STATE_ROOT: "FC_PROTO_MALFORMED_STATE_ROOT",
  INVALID_BRIDGE_SOURCE_CHAIN: "FC_PROTO_INVALID_BRIDGE_SOURCE_CHAIN",
  DUPLICATE_BRIDGE_EVENT: "FC_PROTO_DUPLICATE_BRIDGE_EVENT",
  SCHEMA: "FC_PROTO_SCHEMA_VALIDATION"
};

const MASK_64 = (1n << 64n) - 1n;
const KECCAK_ROT = [
  0, 1, 62, 28, 27,
  36, 44, 6, 55, 20,
  3, 10, 43, 25, 39,
  41, 45, 15, 21, 8,
  18, 2, 61, 56, 14
];
const KECCAK_RC = [
  0x0000000000000001n, 0x0000000000008082n, 0x800000000000808an,
  0x8000000080008000n, 0x000000000000808bn, 0x0000000080000001n,
  0x8000000080008081n, 0x8000000000008009n, 0x000000000000008an,
  0x0000000000000088n, 0x0000000080008009n, 0x000000008000000an,
  0x000000008000808bn, 0x800000000000008bn, 0x8000000000008089n,
  0x8000000000008003n, 0x8000000000008002n, 0x8000000000000080n,
  0x000000000000800an, 0x800000008000000an, 0x8000000080008081n,
  0x8000000000008080n, 0x0000000080000001n, 0x8000000080008008n
];

function rot64(value, shift) {
  const n = BigInt(shift);
  if (n === 0n) return value & MASK_64;
  return ((value << n) | (value >> (64n - n))) & MASK_64;
}

function keccakF(state) {
  for (const rc of KECCAK_RC) {
    const c = new Array(5).fill(0n);
    const d = new Array(5).fill(0n);
    for (let x = 0; x < 5; x += 1) {
      c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
    }
    for (let x = 0; x < 5; x += 1) {
      d[x] = c[(x + 4) % 5] ^ rot64(c[(x + 1) % 5], 1);
    }
    for (let y = 0; y < 5; y += 1) {
      for (let x = 0; x < 5; x += 1) {
        state[x + 5 * y] = (state[x + 5 * y] ^ d[x]) & MASK_64;
      }
    }

    const b = new Array(25).fill(0n);
    for (let y = 0; y < 5; y += 1) {
      for (let x = 0; x < 5; x += 1) {
        b[y + 5 * ((2 * x + 3 * y) % 5)] = rot64(state[x + 5 * y], KECCAK_ROT[x + 5 * y]);
      }
    }
    for (let y = 0; y < 5; y += 1) {
      for (let x = 0; x < 5; x += 1) {
        state[x + 5 * y] = (b[x + 5 * y] ^ ((~b[((x + 1) % 5) + 5 * y]) & b[((x + 2) % 5) + 5 * y])) & MASK_64;
      }
    }
    state[0] = (state[0] ^ rc) & MASK_64;
  }
}

function keccak256(bytes) {
  const rate = 136;
  const state = new Array(25).fill(0n);
  let offset = 0;
  while (bytes.length - offset >= rate) {
    absorbBlock(state, bytes.subarray(offset, offset + rate));
    keccakF(state);
    offset += rate;
  }
  const block = new Uint8Array(rate);
  block.set(bytes.subarray(offset));
  block[bytes.length - offset] ^= 0x01;
  block[rate - 1] ^= 0x80;
  absorbBlock(state, block);
  keccakF(state);

  const out = new Uint8Array(32);
  for (let i = 0; i < out.length; i += 1) {
    out[i] = Number((state[Math.floor(i / 8)] >> BigInt(8 * (i % 8))) & 0xffn);
  }
  return out;
}

function absorbBlock(state, block) {
  for (let lane = 0; lane < block.length / 8; lane += 1) {
    let value = 0n;
    for (let i = 0; i < 8; i += 1) {
      value |= BigInt(block[lane * 8 + i]) << BigInt(8 * i);
    }
    state[lane] = (state[lane] ^ value) & MASK_64;
  }
}

function bytesToHex(bytes) {
  return `0x${Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

function utf8(value) {
  return new TextEncoder().encode(value);
}

function keccakHex(value) {
  return bytesToHex(keccak256(typeof value === "string" ? utf8(value) : value));
}

function canonicalJson(value) {
  return JSON.stringify(normalize(value));
}

function normalize(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => normalize(entry));
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, normalize(value[key])]));
  }
  return value;
}

function hashJson(domain, value) {
  return keccakHex(`${domain}:${canonicalJson(value)}`);
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function prop(owner, value) {
  return { ...value, "x-owner": owner };
}

function ref(name) {
  return { "$ref": `https://flowmemory.local/schemas/flowmemory/${name}` };
}

function defs() {
  return {
    hex32: { type: "string", pattern: "^0x[0-9a-fA-F]{64}$" },
    address: { type: "string", pattern: "^0x[0-9a-fA-F]{40}$" },
    publicKey: { type: "string", pattern: "^0x(02|03)[0-9a-fA-F]{64}$" },
    uintString: { type: "string", pattern: "^(0|[1-9][0-9]*)$" },
    isoTime: { type: "string", format: "date-time" },
    networkProfile: { type: "string", enum: PROFILE_IDS },
    payloadType: { type: "string", enum: PAYLOAD_TYPES },
    eventType: { type: "string", enum: EVENT_TYPES },
    stateComponent: { type: "string", enum: STATE_COMPONENTS }
  };
}

function schemaDoc(fileName, title, body) {
  return {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": `https://flowmemory.local/schemas/flowmemory/${fileName}`,
    title,
    ...body
  };
}

function buildSchemas() {
  const commonDefs = defs();
  const schemas = {};

  schemas["production-network-profile.schema.json"] = schemaDoc("production-network-profile.schema.json", "FlowChain Private/Local Network Profile V0", {
    type: "object",
    additionalProperties: false,
    required: [
      "schema",
      "profileId",
      "legacyAliases",
      "chainId",
      "networkName",
      "destinationScope",
      "genesisHashRules",
      "allowedBridgeSourceChainIds",
      "finalityRule",
      "blockTimeTargetMs",
      "defaultDataDirectory",
      "allowedTransactionFamilies",
      "productionReady",
      "publicMainnetReady"
    ],
    properties: {
      schema: prop("protocol", { const: PROFILE_SCHEMA }),
      profileId: prop("protocol", commonDefs.networkProfile),
      legacyAliases: prop("protocol", { type: "array", items: { enum: ["flowchain-local", "flowchain-private-lan"] }, uniqueItems: true }),
      chainId: prop("runtime", commonDefs.uintString),
      networkName: prop("runtime", { type: "string", minLength: 1 }),
      destinationScope: prop("runtime", { enum: ["local_private"] }),
      genesisHashRules: prop("crypto", {
        type: "object",
        additionalProperties: false,
        required: ["hashAlgorithm", "canonicalization", "domain", "inputFields"],
        properties: {
          hashAlgorithm: prop("crypto", { const: "keccak256" }),
          canonicalization: prop("crypto", { const: "canonical-json-sorted-keys-v0" }),
          domain: prop("crypto", { const: "flowchain.production_l1.genesis_hash.v0" }),
          inputFields: prop("crypto", {
            type: "array",
            minItems: 8,
            items: { type: "string" }
          })
        }
      }),
      allowedBridgeSourceChainIds: prop("bridge", { type: "array", items: { type: "integer", enum: [31337, 84532, 8453] }, uniqueItems: true }),
      finalityRule: prop("consensus", {
        type: "object",
        additionalProperties: false,
        required: ["rule", "requiredConfirmations", "quorum"],
        properties: {
          rule: prop("consensus", { enum: ["single_authority_instant", "quorum_2f_plus_1_checkpoint", "source_base_confirmed_destination_local_finalized"] }),
          requiredConfirmations: prop("consensus", { type: "integer", minimum: 0 }),
          quorum: prop("consensus", { type: "string", pattern: "^[0-9]+/[0-9]+$" })
        }
      }),
      blockTimeTargetMs: prop("runtime", { type: "integer", minimum: 0 }),
      defaultDataDirectory: prop("runtime", { type: "string", minLength: 1 }),
      allowedTransactionFamilies: prop("runtime", { type: "array", items: commonDefs.payloadType, minItems: 1, uniqueItems: true }),
      productionReady: prop("hq-review", { const: false }),
      publicMainnetReady: prop("hq-review", { const: false })
    },
    "$defs": commonDefs
  });

  schemas["production-account-public-metadata.schema.json"] = schemaDoc("production-account-public-metadata.schema.json", "FlowChain Account Public Metadata V0", {
    type: "object",
    additionalProperties: false,
    required: [
      "schema",
      "accountId",
      "label",
      "publicKey",
      "address",
      "addressDerivation",
      "nonceDomain",
      "roleFlags",
      "metadataHash",
      "status",
      "productionReady"
    ],
    properties: {
      schema: prop("wallet", { const: ACCOUNT_SCHEMA }),
      accountId: prop("wallet", commonDefs.hex32),
      label: prop("wallet", { type: "string", minLength: 1 }),
      publicKey: prop("wallet", commonDefs.publicKey),
      address: prop("wallet", commonDefs.address),
      addressDerivation: prop("wallet", {
        type: "object",
        additionalProperties: false,
        required: ["algorithm", "preimageFields", "chainIdBinding"],
        properties: {
          algorithm: prop("wallet", { const: "keccak256(compressedSecp256k1PublicKey)[12:32]" }),
          preimageFields: prop("wallet", { type: "array", items: { enum: ["publicKey", "chainId", "networkProfile"] }, minItems: 3, uniqueItems: true }),
          chainIdBinding: prop("wallet", { const: true })
        }
      }),
      nonceDomain: prop("runtime", {
        type: "object",
        additionalProperties: false,
        required: ["domainId", "nextNonce", "replayScope"],
        properties: {
          domainId: prop("runtime", commonDefs.hex32),
          nextNonce: prop("runtime", commonDefs.uintString),
          replayScope: prop("runtime", { const: "chainId+networkProfile+genesisHash+accountId" })
        }
      }),
      roleFlags: prop("wallet", {
        type: "object",
        additionalProperties: false,
        required: ["user", "validator", "bridgeOperator", "deployer", "relayer", "emergencyOperator"],
        properties: {
          user: prop("wallet", { type: "boolean" }),
          validator: prop("wallet", { type: "boolean" }),
          bridgeOperator: prop("wallet", { type: "boolean" }),
          deployer: prop("wallet", { type: "boolean" }),
          relayer: prop("wallet", { type: "boolean" }),
          emergencyOperator: prop("wallet", { type: "boolean" })
        }
      }),
      metadataHash: prop("wallet", commonDefs.hex32),
      status: prop("runtime", { enum: ["active", "inactive"] }),
      productionReady: prop("hq-review", { const: false })
    },
    "$defs": commonDefs
  });

  schemas["production-validator-authority.schema.json"] = schemaDoc("production-validator-authority.schema.json", "FlowChain Validator Authority V0", {
    type: "object",
    additionalProperties: false,
    required: [
      "schema",
      "authorityId",
      "accountId",
      "publicKey",
      "address",
      "authorityType",
      "votingPower",
      "finalityWeight",
      "metadataHash",
      "status",
      "productionReady"
    ],
    properties: {
      schema: prop("consensus", { const: AUTHORITY_SCHEMA }),
      authorityId: prop("consensus", commonDefs.hex32),
      accountId: prop("consensus", commonDefs.hex32),
      publicKey: prop("consensus", commonDefs.publicKey),
      address: prop("consensus", commonDefs.address),
      authorityType: prop("consensus", { enum: ["validator", "sequencer", "local-authority", "finality-voter", "bridge-release-authority"] }),
      votingPower: prop("consensus", commonDefs.uintString),
      finalityWeight: prop("consensus", commonDefs.uintString),
      metadataHash: prop("consensus", commonDefs.hex32),
      status: prop("consensus", { enum: ["active", "inactive"] }),
      productionReady: prop("hq-review", { const: false })
    },
    "$defs": commonDefs
  });

  schemas["production-genesis.schema.json"] = schemaDoc("production-genesis.schema.json", "FlowChain Genesis V0", {
    type: "object",
    additionalProperties: false,
    required: [
      "schema",
      "protocolVersion",
      "networkProfile",
      "chainId",
      "networkName",
      "genesisTimestamp",
      "genesisUnixMs",
      "stateRootSeed",
      "initialAccounts",
      "initialBalances",
      "validatorSet",
      "bridgePilotConfig",
      "tokenDexBootstrapConfig",
      "genesisHashInput",
      "genesisHash",
      "productionReady"
    ],
    properties: {
      schema: prop("runtime", { const: GENESIS_SCHEMA }),
      protocolVersion: prop("protocol", { const: PROTOCOL_VERSION }),
      networkProfile: prop("runtime", commonDefs.networkProfile),
      chainId: prop("runtime", commonDefs.uintString),
      networkName: prop("runtime", { type: "string", minLength: 1 }),
      genesisTimestamp: prop("runtime", commonDefs.isoTime),
      genesisUnixMs: prop("runtime", commonDefs.uintString),
      stateRootSeed: prop("crypto", commonDefs.hex32),
      initialAccounts: prop("wallet", { type: "array", minItems: 1, items: ref("production-account-public-metadata.schema.json") }),
      initialBalances: prop("runtime", {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["accountId", "assetId", "amount", "balanceType", "noValue"],
          properties: {
            accountId: prop("runtime", commonDefs.hex32),
            assetId: prop("runtime", commonDefs.hex32),
            amount: prop("runtime", commonDefs.uintString),
            balanceType: prop("runtime", { enum: ["native_local_unit", "test_token"] }),
            noValue: prop("hq-review", { const: true })
          }
        }
      }),
      validatorSet: prop("consensus", { type: "array", minItems: 1, items: ref("production-validator-authority.schema.json") }),
      bridgePilotConfig: prop("bridge", {
        type: "object",
        additionalProperties: false,
        required: ["enabled", "sourceChainId", "sourceNetwork", "destinationProfile", "lockboxAddress", "releaseAuthorityAccountId", "relayerAccountId", "duplicatePolicy", "productionReady"],
        properties: {
          enabled: prop("bridge", { type: "boolean" }),
          sourceChainId: prop("bridge", { type: "integer", enum: [8453] }),
          sourceNetwork: prop("bridge", { const: "base-mainnet-source-for-local-private-pilot" }),
          destinationProfile: prop("bridge", { const: "flowchain-base8453-pilot" }),
          lockboxAddress: prop("bridge", commonDefs.address),
          releaseAuthorityAccountId: prop("bridge", commonDefs.hex32),
          relayerAccountId: prop("bridge", commonDefs.hex32),
          duplicatePolicy: prop("bridge", { const: "reject_same_source_chain_lockbox_tx_hash_log_index" }),
          productionReady: prop("hq-review", { const: false })
        }
      }),
      tokenDexBootstrapConfig: prop("runtime", {
        type: "object",
        additionalProperties: false,
        required: ["nativeAssetId", "localTokenLaunchAllowed", "localTokenMintAllowed", "dexBootstrapAllowed", "defaultFeeBps", "productionReady"],
        properties: {
          nativeAssetId: prop("runtime", commonDefs.hex32),
          localTokenLaunchAllowed: prop("runtime", { const: true }),
          localTokenMintAllowed: prop("runtime", { const: true }),
          dexBootstrapAllowed: prop("runtime", { const: true }),
          defaultFeeBps: prop("runtime", { type: "integer", minimum: 0, maximum: 10000 }),
          productionReady: prop("hq-review", { const: false })
        }
      }),
      genesisHashInput: prop("crypto", {
        type: "object",
        additionalProperties: false,
        required: ["schema", "protocolVersion", "networkProfile", "chainId", "genesisTimestamp", "stateRootSeed", "initialAccountsRoot", "initialBalancesRoot", "validatorSetRoot", "bridgePilotConfigHash", "tokenDexBootstrapConfigHash"],
        properties: {
          schema: prop("crypto", { const: "flowchain.production_l1.genesis_hash_input.v0" }),
          protocolVersion: prop("crypto", { const: PROTOCOL_VERSION }),
          networkProfile: prop("crypto", commonDefs.networkProfile),
          chainId: prop("crypto", commonDefs.uintString),
          genesisTimestamp: prop("crypto", commonDefs.isoTime),
          stateRootSeed: prop("crypto", commonDefs.hex32),
          initialAccountsRoot: prop("crypto", commonDefs.hex32),
          initialBalancesRoot: prop("crypto", commonDefs.hex32),
          validatorSetRoot: prop("crypto", commonDefs.hex32),
          bridgePilotConfigHash: prop("crypto", commonDefs.hex32),
          tokenDexBootstrapConfigHash: prop("crypto", commonDefs.hex32)
        }
      }),
      genesisHash: prop("crypto", commonDefs.hex32),
      productionReady: prop("hq-review", { const: false })
    },
    "$defs": commonDefs
  });

  schemas["production-transaction-payload.schema.json"] = buildPayloadSchema(commonDefs);
  schemas["production-transaction-envelope.schema.json"] = buildEnvelopeSchema(commonDefs);
  schemas["production-event.schema.json"] = buildEventSchema(commonDefs);
  schemas["production-receipt.schema.json"] = buildReceiptSchema(commonDefs);
  schemas["production-block-header.schema.json"] = buildBlockHeaderSchema(commonDefs);
  schemas["production-bridge-evidence.schema.json"] = buildBridgeEvidenceSchema(commonDefs);
  schemas["production-state-root-manifest.schema.json"] = buildStateRootSchema(commonDefs);
  schemas["production-finality-receipt.schema.json"] = buildFinalitySchema(commonDefs);
  schemas["production-block-body.schema.json"] = buildBlockBodySchema(commonDefs);
  schemas["production-export-snapshot.schema.json"] = buildExportSnapshotSchema(commonDefs);

  return schemas;
}

function buildPayloadSchema(commonDefs) {
  const hex = commonDefs.hex32;
  const uint = commonDefs.uintString;
  const details = {
    native_transfer: {
      required: ["fromAccountId", "toAccountId", "assetId", "amount", "memoHash"],
      properties: { fromAccountId: prop("runtime", hex), toAccountId: prop("runtime", hex), assetId: prop("runtime", hex), amount: prop("runtime", uint), memoHash: prop("wallet", hex) }
    },
    faucet_funding: {
      required: ["faucetId", "toAccountId", "assetId", "amount", "reasonHash", "localOnly"],
      properties: { faucetId: prop("runtime", hex), toAccountId: prop("runtime", hex), assetId: prop("runtime", hex), amount: prop("runtime", uint), reasonHash: prop("runtime", hex), localOnly: prop("hq-review", { const: true }) }
    },
    bridge_credit: {
      required: ["bridgeEvidenceId", "observationId", "creditId", "sourceChainId", "assetId", "amount", "recipientAccountId"],
      properties: { bridgeEvidenceId: prop("bridge", hex), observationId: prop("bridge", hex), creditId: prop("bridge", hex), sourceChainId: prop("bridge", { type: "integer", enum: [31337, 84532, 8453] }), assetId: prop("bridge", hex), amount: prop("bridge", uint), recipientAccountId: prop("bridge", hex) }
    },
    token_launch: {
      required: ["tokenLaunchId", "issuerAccountId", "tokenId", "symbol", "name", "decimals", "metadataHash", "initialSupply", "recipientAccountId"],
      properties: { tokenLaunchId: prop("runtime", hex), issuerAccountId: prop("runtime", hex), tokenId: prop("runtime", hex), symbol: prop("wallet", { type: "string", pattern: "^[A-Z0-9]{2,12}$" }), name: prop("wallet", { type: "string", minLength: 1 }), decimals: prop("runtime", { type: "integer", minimum: 0, maximum: 18 }), metadataHash: prop("runtime", hex), initialSupply: prop("runtime", uint), recipientAccountId: prop("runtime", hex) }
    },
    token_mint: {
      required: ["mintId", "tokenId", "toAccountId", "amount", "reasonHash", "localOrTestMode"],
      properties: { mintId: prop("runtime", hex), tokenId: prop("runtime", hex), toAccountId: prop("runtime", hex), amount: prop("runtime", uint), reasonHash: prop("runtime", hex), localOrTestMode: prop("hq-review", { const: true }) }
    },
    token_transfer: {
      required: ["tokenTransferId", "tokenId", "fromAccountId", "toAccountId", "amount", "memoHash"],
      properties: { tokenTransferId: prop("runtime", hex), tokenId: prop("runtime", hex), fromAccountId: prop("runtime", hex), toAccountId: prop("runtime", hex), amount: prop("runtime", uint), memoHash: prop("wallet", hex) }
    },
    pool_create: {
      required: ["poolCreateId", "creatorAccountId", "poolId", "baseAssetId", "quoteAssetId", "feeBps", "tickSpacing", "metadataHash"],
      properties: { poolCreateId: prop("runtime", hex), creatorAccountId: prop("runtime", hex), poolId: prop("runtime", hex), baseAssetId: prop("runtime", hex), quoteAssetId: prop("runtime", hex), feeBps: prop("runtime", { type: "integer", minimum: 0, maximum: 10000 }), tickSpacing: prop("runtime", { type: "integer", minimum: 1 }), metadataHash: prop("runtime", hex) }
    },
    add_liquidity: {
      required: ["liquidityId", "poolId", "providerAccountId", "baseAmount", "quoteAmount", "minLpUnits"],
      properties: { liquidityId: prop("runtime", hex), poolId: prop("runtime", hex), providerAccountId: prop("runtime", hex), baseAmount: prop("runtime", uint), quoteAmount: prop("runtime", uint), minLpUnits: prop("runtime", uint) }
    },
    remove_liquidity: {
      required: ["liquidityId", "poolId", "providerAccountId", "lpUnits", "minBaseAmount", "minQuoteAmount"],
      properties: { liquidityId: prop("runtime", hex), poolId: prop("runtime", hex), providerAccountId: prop("runtime", hex), lpUnits: prop("runtime", uint), minBaseAmount: prop("runtime", uint), minQuoteAmount: prop("runtime", uint) }
    },
    swap: {
      required: ["swapId", "poolId", "traderAccountId", "assetInId", "assetOutId", "amountIn", "minAmountOut", "routeHash"],
      properties: { swapId: prop("runtime", hex), poolId: prop("runtime", hex), traderAccountId: prop("runtime", hex), assetInId: prop("runtime", hex), assetOutId: prop("runtime", hex), amountIn: prop("runtime", uint), minAmountOut: prop("runtime", uint), routeHash: prop("runtime", hex) }
    },
    withdrawal_intent: {
      required: ["withdrawalIntentId", "sourceAccountId", "destinationChainId", "destinationAddress", "assetId", "amount", "releasePolicyHash"],
      properties: { withdrawalIntentId: prop("bridge", hex), sourceAccountId: prop("bridge", hex), destinationChainId: prop("bridge", { type: "integer", enum: [8453] }), destinationAddress: prop("bridge", commonDefs.address), assetId: prop("bridge", hex), amount: prop("bridge", uint), releasePolicyHash: prop("bridge", hex) }
    },
    validator_authority_config: {
      required: ["authorityConfigId", "authorityId", "validatorAccountId", "action", "authorityType", "votingPower", "metadataHash"],
      properties: { authorityConfigId: prop("consensus", hex), authorityId: prop("consensus", hex), validatorAccountId: prop("consensus", hex), action: prop("consensus", { enum: ["register", "update"] }), authorityType: prop("consensus", { enum: ["validator", "sequencer", "local-authority", "finality-voter"] }), votingPower: prop("consensus", uint), metadataHash: prop("consensus", hex) }
    },
    finality_vote: {
      required: ["voteId", "validatorAccountId", "height", "blockHash", "stateRoot", "voteRound"],
      properties: { voteId: prop("consensus", hex), validatorAccountId: prop("consensus", hex), height: prop("consensus", uint), blockHash: prop("consensus", hex), stateRoot: prop("consensus", hex), voteRound: prop("consensus", uint) }
    },
    finality_certificate: {
      required: ["certificateId", "height", "blockHash", "stateRoot", "signerSetRoot", "voteIds", "quorumNumerator", "quorumDenominator"],
      properties: { certificateId: prop("consensus", hex), height: prop("consensus", uint), blockHash: prop("consensus", hex), stateRoot: prop("consensus", hex), signerSetRoot: prop("consensus", hex), voteIds: prop("consensus", { type: "array", items: hex, minItems: 1 }), quorumNumerator: prop("consensus", { type: "integer", minimum: 1 }), quorumDenominator: prop("consensus", { type: "integer", minimum: 1 }) }
    }
  };

  for (const payloadType of OBJECT_PAYLOAD_TYPES) {
    const objectType = objectTypeForPayload(payloadType);
    details[payloadType] = {
      required: ["lifecycleUpdateId", "objectType", "operation", "objectId", "objectHash", "status", "rootfieldId"],
      properties: {
        lifecycleUpdateId: prop("runtime", hex),
        objectType: prop("runtime", { const: objectType }),
        operation: prop("runtime", { enum: ["create", "update", "status_change", "finalize"] }),
        objectId: prop("runtime", hex),
        objectHash: prop("crypto", hex),
        status: prop("runtime", { enum: ["active", "pending", "verified", "failed", "resolved", "finalized", "superseded"] }),
        rootfieldId: prop("runtime", hex),
        sourceReceiptId: prop("runtime", { anyOf: [hex, { type: "null" }] }),
        parentObjectId: prop("runtime", { anyOf: [hex, { type: "null" }] })
      }
    };
  }

  return schemaDoc("production-transaction-payload.schema.json", "FlowChain Transaction Payload Union V0", {
    oneOf: PAYLOAD_TYPES.map((payloadType) => payloadVariant(payloadType, details[payloadType], commonDefs)),
    "$defs": commonDefs
  });
}

function payloadVariant(payloadType, detail, commonDefs) {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "schema",
      "payloadType",
      "payloadId",
      "actorAccountId",
      "accountNonce",
      "details",
      "preconditions",
      "stateWrites",
      "balanceChanges",
      "nonceChange",
      "emittedEventTypes",
      "indexKeys",
      "localOnly",
      "productionReady"
    ],
    properties: {
      schema: prop("runtime", { const: PAYLOAD_SCHEMA }),
      payloadType: prop("runtime", { const: payloadType }),
      payloadId: prop("runtime", commonDefs.hex32),
      actorAccountId: prop("wallet", commonDefs.hex32),
      accountNonce: prop("runtime", commonDefs.uintString),
      details: prop(payloadOwner(payloadType), {
        type: "object",
        additionalProperties: false,
        required: detail.required,
        properties: detail.properties
      }),
      preconditions: prop("runtime", { type: "array", items: { type: "string", minLength: 1 }, minItems: 1 }),
      stateWrites: prop("runtime", { type: "array", items: { type: "string", minLength: 1 }, minItems: 1 }),
      balanceChanges: prop("runtime", {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["accountId", "assetId", "delta"],
          properties: {
            accountId: prop("runtime", commonDefs.hex32),
            assetId: prop("runtime", commonDefs.hex32),
            delta: prop("runtime", { type: "string", pattern: "^-?(0|[1-9][0-9]*)$" })
          }
        }
      }),
      nonceChange: prop("runtime", {
        type: "object",
        additionalProperties: false,
        required: ["accountId", "before", "after"],
        properties: {
          accountId: prop("runtime", commonDefs.hex32),
          before: prop("runtime", commonDefs.uintString),
          after: prop("runtime", commonDefs.uintString)
        }
      }),
      emittedEventTypes: prop("indexer", { type: "array", minItems: 1, items: commonDefs.eventType }),
      indexKeys: prop("indexer", {
        type: "array",
        minItems: 1,
        items: {
          type: "object",
          additionalProperties: false,
          required: ["key", "value"],
          properties: {
            key: prop("indexer", { type: "string", minLength: 1 }),
            value: prop("indexer", { type: "string", minLength: 1 })
          }
        }
      }),
      localOnly: prop("hq-review", { const: true }),
      productionReady: prop("hq-review", { const: false })
    }
  };
}

function buildEnvelopeSchema(commonDefs) {
  return schemaDoc("production-transaction-envelope.schema.json", "FlowChain Transaction Envelope V0", {
    type: "object",
    additionalProperties: false,
    required: [
      "schema",
      "txId",
      "protocolVersion",
      "chainId",
      "networkProfile",
      "genesisHash",
      "nonce",
      "nonceDomain",
      "signer",
      "payloadType",
      "payloadHash",
      "payload",
      "fee",
      "expiration",
      "signature"
    ],
    properties: {
      schema: prop("crypto", { const: ENVELOPE_SCHEMA }),
      txId: prop("crypto", commonDefs.hex32),
      protocolVersion: prop("protocol", { const: PROTOCOL_VERSION }),
      chainId: prop("runtime", commonDefs.uintString),
      networkProfile: prop("runtime", commonDefs.networkProfile),
      genesisHash: prop("crypto", commonDefs.hex32),
      nonce: prop("runtime", commonDefs.uintString),
      nonceDomain: prop("runtime", commonDefs.hex32),
      signer: prop("wallet", {
        type: "object",
        additionalProperties: false,
        required: ["accountId", "publicKey", "address", "role"],
        properties: {
          accountId: prop("wallet", commonDefs.hex32),
          publicKey: prop("wallet", commonDefs.publicKey),
          address: prop("wallet", commonDefs.address),
          role: prop("wallet", { enum: ["user", "validator", "bridge_operator", "deployer", "relayer", "emergency_operator"] })
        }
      }),
      payloadType: prop("runtime", commonDefs.payloadType),
      payloadHash: prop("crypto", commonDefs.hex32),
      payload: prop("runtime", ref("production-transaction-payload.schema.json")),
      fee: prop("runtime", {
        type: "object",
        additionalProperties: false,
        required: ["mode", "gasLimit", "maxFeePerGas", "localExecutionCostLimit"],
        properties: {
          mode: prop("runtime", { enum: ["no_fee_local", "local_gas_units"] }),
          gasLimit: prop("runtime", commonDefs.uintString),
          maxFeePerGas: prop("runtime", commonDefs.uintString),
          localExecutionCostLimit: prop("runtime", commonDefs.uintString)
        }
      }),
      expiration: prop("runtime", {
        type: "object",
        additionalProperties: false,
        required: ["validAfterBlock", "validUntilBlock", "expiresAtUnixMs"],
        properties: {
          validAfterBlock: prop("runtime", commonDefs.uintString),
          validUntilBlock: prop("runtime", commonDefs.uintString),
          expiresAtUnixMs: prop("runtime", commonDefs.uintString)
        }
      }),
      signature: prop("crypto", {
        type: "object",
        additionalProperties: false,
        required: ["scheme", "signingDigest", "value"],
        properties: {
          scheme: prop("crypto", { const: "fixture-secp256k1-digest-only" }),
          signingDigest: prop("crypto", commonDefs.hex32),
          value: prop("crypto", { type: "string", pattern: "^0x[0-9a-fA-F]{128}$" })
        }
      })
    },
    "$defs": commonDefs
  });
}

function buildEventSchema(commonDefs) {
  return schemaDoc("production-event.schema.json", "FlowChain Event V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "eventId", "eventType", "payloadType", "txId", "receiptId", "blockHeight", "eventIndex", "emitterAccountId", "subjectId", "attributes", "deterministicIdInput"],
    properties: {
      schema: prop("indexer", { const: EVENT_SCHEMA }),
      eventId: prop("indexer", commonDefs.hex32),
      eventType: prop("indexer", commonDefs.eventType),
      payloadType: prop("indexer", commonDefs.payloadType),
      txId: prop("indexer", commonDefs.hex32),
      receiptId: prop("indexer", commonDefs.hex32),
      blockHeight: prop("runtime", commonDefs.uintString),
      eventIndex: prop("indexer", { type: "integer", minimum: 0 }),
      emitterAccountId: prop("indexer", commonDefs.hex32),
      subjectId: prop("indexer", commonDefs.hex32),
      attributes: prop("indexer", {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["key", "value", "valueType"],
          properties: {
            key: prop("indexer", { type: "string", minLength: 1 }),
            value: prop("indexer", { type: "string" }),
            valueType: prop("indexer", { enum: ["hex32", "address", "uint", "string", "bool"] })
          }
        }
      }),
      deterministicIdInput: prop("crypto", commonDefs.hex32)
    },
    "$defs": commonDefs
  });
}

function buildReceiptSchema(commonDefs) {
  return schemaDoc("production-receipt.schema.json", "FlowChain Receipt V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "receiptId", "txId", "payloadType", "status", "executionCost", "stateDeltaRef", "emittedEvents", "bridgeEvidenceRefs", "errorCode", "failureReason", "deterministicIdInput"],
    properties: {
      schema: prop("runtime", { const: RECEIPT_SCHEMA }),
      receiptId: prop("runtime", commonDefs.hex32),
      txId: prop("runtime", commonDefs.hex32),
      payloadType: prop("runtime", commonDefs.payloadType),
      status: prop("runtime", { enum: ["succeeded", "failed"] }),
      executionCost: prop("runtime", {
        type: "object",
        additionalProperties: false,
        required: ["costUnits", "meter"],
        properties: {
          costUnits: prop("runtime", commonDefs.uintString),
          meter: prop("runtime", { enum: ["local_execution_units", "local_gas_units"] })
        }
      }),
      stateDeltaRef: prop("runtime", commonDefs.hex32),
      emittedEvents: prop("indexer", { type: "array", items: commonDefs.hex32 }),
      bridgeEvidenceRefs: prop("bridge", { type: "array", items: commonDefs.hex32 }),
      errorCode: prop("rpc", { anyOf: [{ type: "string", pattern: "^FC_[A-Z0-9_]+$" }, { type: "null" }] }),
      failureReason: prop("rpc", {
        anyOf: [
          {
            type: "object",
            additionalProperties: false,
            required: ["reasonCode", "displayMessage", "retryable"],
            properties: {
              reasonCode: prop("rpc", { type: "string", pattern: "^FC_[A-Z0-9_]+$" }),
              displayMessage: prop("dashboard", { type: "string", minLength: 1 }),
              retryable: prop("rpc", { type: "boolean" })
            }
          },
          { type: "null" }
        ]
      }),
      deterministicIdInput: prop("crypto", commonDefs.hex32)
    },
    "$defs": commonDefs
  });
}

function buildBlockHeaderSchema(commonDefs) {
  return schemaDoc("production-block-header.schema.json", "FlowChain Block Header V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "chainId", "networkProfile", "genesisHash", "height", "parentHash", "timestamp", "proposer", "txRoot", "receiptRoot", "eventRoot", "stateRoot", "evidenceRoot", "finalizedHeight", "protocolVersion", "blockHash"],
    properties: {
      schema: prop("runtime", { const: BLOCK_HEADER_SCHEMA }),
      chainId: prop("runtime", commonDefs.uintString),
      networkProfile: prop("runtime", commonDefs.networkProfile),
      genesisHash: prop("runtime", commonDefs.hex32),
      height: prop("runtime", commonDefs.uintString),
      parentHash: prop("runtime", commonDefs.hex32),
      timestamp: prop("runtime", commonDefs.isoTime),
      proposer: prop("consensus", commonDefs.hex32),
      txRoot: prop("runtime", commonDefs.hex32),
      receiptRoot: prop("runtime", commonDefs.hex32),
      eventRoot: prop("runtime", commonDefs.hex32),
      stateRoot: prop("runtime", commonDefs.hex32),
      evidenceRoot: prop("runtime", commonDefs.hex32),
      finalizedHeight: prop("consensus", commonDefs.uintString),
      protocolVersion: prop("protocol", { const: PROTOCOL_VERSION }),
      blockHash: prop("crypto", commonDefs.hex32)
    },
    "$defs": commonDefs
  });
}

function buildBridgeEvidenceSchema(commonDefs) {
  return schemaDoc("production-bridge-evidence.schema.json", "FlowChain Bridge Evidence V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "evidenceId", "evidenceType", "sourceChainId", "sourceNetwork", "lockboxAddress", "sourceTxHash", "sourceBlockNumber", "sourceLogIndex", "tokenAddress", "assetId", "depositorAddress", "localRecipientAccountId", "amount", "observationId", "creditId", "duplicateKey", "evidenceHash", "observedByRelayerAccountId", "finalityStatus", "release", "localOnly", "productionReady"],
    properties: {
      schema: prop("bridge", { const: BRIDGE_EVIDENCE_SCHEMA }),
      evidenceId: prop("bridge", commonDefs.hex32),
      evidenceType: prop("bridge", { enum: ["deposit_observation", "withdrawal_release"] }),
      sourceChainId: prop("bridge", { type: "integer", enum: [31337, 84532, 8453] }),
      sourceNetwork: prop("bridge", { enum: ["base-mainnet-source-for-local-private-pilot", "base-sepolia-test-source", "local-anvil-test-source"] }),
      lockboxAddress: prop("bridge", commonDefs.address),
      sourceTxHash: prop("bridge", commonDefs.hex32),
      sourceBlockNumber: prop("bridge", commonDefs.uintString),
      sourceLogIndex: prop("bridge", { type: "integer", minimum: 0 }),
      tokenAddress: prop("bridge", commonDefs.address),
      assetId: prop("bridge", commonDefs.hex32),
      depositorAddress: prop("bridge", commonDefs.address),
      localRecipientAccountId: prop("bridge", commonDefs.hex32),
      amount: prop("bridge", commonDefs.uintString),
      observationId: prop("bridge", commonDefs.hex32),
      creditId: prop("bridge", commonDefs.hex32),
      duplicateKey: prop("bridge", commonDefs.hex32),
      evidenceHash: prop("bridge", commonDefs.hex32),
      observedByRelayerAccountId: prop("bridge", commonDefs.hex32),
      finalityStatus: prop("bridge", { enum: ["source_finalized", "source_pending", "source_rejected"] }),
      release: prop("bridge", {
        anyOf: [
          {
            type: "object",
            additionalProperties: false,
            required: ["withdrawalIntentId", "releaseTxHash", "releaseBlockNumber", "releaseLogIndex", "releasedToAddress", "releaseAuthorityAccountId"],
            properties: {
              withdrawalIntentId: prop("bridge", commonDefs.hex32),
              releaseTxHash: prop("bridge", commonDefs.hex32),
              releaseBlockNumber: prop("bridge", commonDefs.uintString),
              releaseLogIndex: prop("bridge", { type: "integer", minimum: 0 }),
              releasedToAddress: prop("bridge", commonDefs.address),
              releaseAuthorityAccountId: prop("bridge", commonDefs.hex32)
            }
          },
          { type: "null" }
        ]
      }),
      localOnly: prop("hq-review", { const: true }),
      productionReady: prop("hq-review", { const: false })
    },
    allOf: [
      {
        if: { properties: { evidenceType: { const: "withdrawal_release" } } },
        then: { properties: { release: { type: "object" } } }
      },
      {
        if: { properties: { evidenceType: { const: "deposit_observation" } } },
        then: { properties: { release: { type: "null" } } }
      }
    ],
    "$defs": commonDefs
  });
}

function buildStateRootSchema(commonDefs) {
  return schemaDoc("production-state-root-manifest.schema.json", "FlowChain State Root Manifest V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "chainId", "networkProfile", "genesisHash", "stateRoot", "stateRootAlgorithm", "components", "stateComponents", "deterministicReplay"],
    properties: {
      schema: prop("runtime", { const: STATE_ROOT_SCHEMA }),
      chainId: prop("runtime", commonDefs.uintString),
      networkProfile: prop("runtime", commonDefs.networkProfile),
      genesisHash: prop("runtime", commonDefs.hex32),
      stateRoot: prop("crypto", commonDefs.hex32),
      stateRootAlgorithm: prop("crypto", { const: "keccak256(canonical-json-sorted-keys-v0)" }),
      components: prop("runtime", {
        type: "array",
        minItems: STATE_COMPONENTS.length,
        items: {
          type: "object",
          additionalProperties: false,
          required: ["component", "root", "count", "ownerAgent", "inputs"],
          properties: {
            component: prop("runtime", commonDefs.stateComponent),
            root: prop("crypto", commonDefs.hex32),
            count: prop("runtime", { type: "integer", minimum: 0 }),
            ownerAgent: prop("protocol", { enum: ["runtime", "wallet", "bridge", "consensus", "indexer"] }),
            inputs: prop("runtime", { type: "array", items: { type: "string", minLength: 1 }, minItems: 1 })
          }
        }
      }),
      stateComponents: prop("runtime", {
        type: "object",
        additionalProperties: true,
        required: STATE_COMPONENTS
      }),
      deterministicReplay: prop("runtime", {
        type: "object",
        additionalProperties: false,
        required: ["sameLogicalStateRoot", "replayCommand"],
        properties: {
          sameLogicalStateRoot: prop("runtime", commonDefs.hex32),
          replayCommand: prop("runtime", { type: "string", minLength: 1 })
        }
      })
    },
    "$defs": commonDefs
  });
}

function buildFinalitySchema(commonDefs) {
  return schemaDoc("production-finality-receipt.schema.json", "FlowChain Finality Receipt V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "finalityReceiptId", "chainId", "networkProfile", "height", "blockHash", "stateRoot", "finalizedHeight", "finalityRule", "status", "validatorSetHash", "certificateHash", "evidenceRoot", "producedAt", "productionReady"],
    properties: {
      schema: prop("consensus", { const: FINALITY_SCHEMA }),
      finalityReceiptId: prop("consensus", commonDefs.hex32),
      chainId: prop("consensus", commonDefs.uintString),
      networkProfile: prop("consensus", commonDefs.networkProfile),
      height: prop("consensus", commonDefs.uintString),
      blockHash: prop("consensus", commonDefs.hex32),
      stateRoot: prop("consensus", commonDefs.hex32),
      finalizedHeight: prop("consensus", commonDefs.uintString),
      finalityRule: prop("consensus", { enum: ["single_authority_instant", "quorum_2f_plus_1_checkpoint", "source_base_confirmed_destination_local_finalized"] }),
      status: prop("consensus", { enum: ["pending", "accepted", "rejected", "superseded", "downgraded"] }),
      validatorSetHash: prop("consensus", commonDefs.hex32),
      certificateHash: prop("consensus", commonDefs.hex32),
      evidenceRoot: prop("consensus", commonDefs.hex32),
      producedAt: prop("consensus", commonDefs.isoTime),
      productionReady: prop("hq-review", { const: false })
    },
    "$defs": commonDefs
  });
}

function buildBlockBodySchema(commonDefs) {
  return schemaDoc("production-block-body.schema.json", "FlowChain Block Body V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "header", "transactions", "receipts", "events", "bridgeEvidence", "stateRootManifest"],
    properties: {
      schema: prop("runtime", { const: BLOCK_BODY_SCHEMA }),
      header: prop("runtime", ref("production-block-header.schema.json")),
      transactions: prop("runtime", { type: "array", minItems: 1, items: ref("production-transaction-envelope.schema.json") }),
      receipts: prop("runtime", { type: "array", minItems: 1, items: ref("production-receipt.schema.json") }),
      events: prop("indexer", { type: "array", minItems: 1, items: ref("production-event.schema.json") }),
      bridgeEvidence: prop("bridge", { type: "array", items: ref("production-bridge-evidence.schema.json") }),
      stateRootManifest: prop("runtime", ref("production-state-root-manifest.schema.json"))
    },
    "$defs": commonDefs
  });
}

function buildExportSnapshotSchema(commonDefs) {
  return schemaDoc("production-export-snapshot.schema.json", "FlowChain Export Snapshot V0", {
    type: "object",
    additionalProperties: false,
    required: ["schema", "chainId", "networkProfile", "genesisHash", "blockHeight", "blockHash", "stateRoot", "stateRootManifest", "accounts", "balances", "tokens", "pools", "bridgeCredits", "withdrawals", "objectStoreRefs", "finalityReceipts", "provenance", "productionReady"],
    properties: {
      schema: prop("runtime", { const: EXPORT_SNAPSHOT_SCHEMA }),
      chainId: prop("runtime", commonDefs.uintString),
      networkProfile: prop("runtime", commonDefs.networkProfile),
      genesisHash: prop("runtime", commonDefs.hex32),
      blockHeight: prop("runtime", commonDefs.uintString),
      blockHash: prop("runtime", commonDefs.hex32),
      stateRoot: prop("runtime", commonDefs.hex32),
      stateRootManifest: prop("runtime", ref("production-state-root-manifest.schema.json")),
      accounts: prop("wallet", { type: "array", items: ref("production-account-public-metadata.schema.json") }),
      balances: prop("runtime", { type: "array" }),
      tokens: prop("runtime", { type: "array" }),
      pools: prop("runtime", { type: "array" }),
      bridgeCredits: prop("bridge", { type: "array" }),
      withdrawals: prop("bridge", { type: "array" }),
      objectStoreRefs: prop("runtime", { type: "array" }),
      finalityReceipts: prop("consensus", { type: "array", items: ref("production-finality-receipt.schema.json") }),
      provenance: prop("rpc", {
        type: "object",
        additionalProperties: false,
        required: ["generatedBy", "schemaNames", "fixturePaths", "validationCommands"],
        properties: {
          generatedBy: prop("rpc", { type: "string", minLength: 1 }),
          schemaNames: prop("rpc", { type: "array", items: { type: "string" }, minItems: 1 }),
          fixturePaths: prop("rpc", { type: "array", items: { type: "string" }, minItems: 1 }),
          validationCommands: prop("rpc", { type: "array", items: { type: "string" }, minItems: 1 })
        }
      }),
      productionReady: prop("hq-review", { const: false })
    },
    "$defs": commonDefs
  });
}

function buildProfiles() {
  const genesisInputFields = [
    "protocolVersion",
    "networkProfile",
    "chainId",
    "genesisTimestamp",
    "stateRootSeed",
    "initialAccountsRoot",
    "initialBalancesRoot",
    "validatorSetRoot",
    "bridgePilotConfigHash",
    "tokenDexBootstrapConfigHash"
  ];
  const base = {
    schema: PROFILE_SCHEMA,
    destinationScope: "local_private",
    genesisHashRules: {
      hashAlgorithm: "keccak256",
      canonicalization: "canonical-json-sorted-keys-v0",
      domain: "flowchain.production_l1.genesis_hash.v0",
      inputFields: genesisInputFields
    },
    allowedTransactionFamilies: PAYLOAD_TYPES,
    productionReady: false,
    publicMainnetReady: false
  };
  return [
    {
      ...base,
      profileId: "flowchain-local-private",
      legacyAliases: ["flowchain-local"],
      chainId: "742001",
      networkName: "FlowChain Local Private",
      allowedBridgeSourceChainIds: [31337],
      finalityRule: { rule: "single_authority_instant", requiredConfirmations: 0, quorum: "1/1" },
      blockTimeTargetMs: 1000,
      defaultDataDirectory: "devnet/local/flowchain-local-private"
    },
    {
      ...base,
      profileId: "flowchain-local-multinode",
      legacyAliases: ["flowchain-private-lan"],
      chainId: "742002",
      networkName: "FlowChain Local Multinode",
      allowedBridgeSourceChainIds: [31337, 84532],
      finalityRule: { rule: "quorum_2f_plus_1_checkpoint", requiredConfirmations: 1, quorum: "2/3" },
      blockTimeTargetMs: 2000,
      defaultDataDirectory: "devnet/local/flowchain-local-multinode"
    },
    {
      ...base,
      profileId: "flowchain-base8453-pilot",
      legacyAliases: [],
      chainId: "7428453",
      networkName: "FlowChain Base 8453 Pilot Destination",
      allowedBridgeSourceChainIds: [8453],
      finalityRule: { rule: "source_base_confirmed_destination_local_finalized", requiredConfirmations: 12, quorum: "1/1" },
      blockTimeTargetMs: 2000,
      defaultDataDirectory: "devnet/local/flowchain-base8453-pilot"
    }
  ];
}

function buildAll() {
  const profiles = buildProfiles();
  const profile = profiles.find((entry) => entry.profileId === "flowchain-base8453-pilot");
  const accounts = buildAccounts(profile);
  const accountByLabel = Object.fromEntries(accounts.map((account) => [account.label, account]));
  const nativeAssetId = hashJson("flowchain.production_l1.asset_id.v0", { symbol: "FLOW-LOCAL", profileId: profile.profileId });
  const tokenId = hashJson("flowchain.production_l1.token_id.v0", { symbol: "FLOWT", profileId: profile.profileId });
  const poolId = hashJson("flowchain.production_l1.pool_id.v0", { baseAssetId: nativeAssetId, quoteAssetId: tokenId });
  const initialBalances = [
    balance(accountByLabel["alice-user"].accountId, nativeAssetId, "1000000"),
    balance(accountByLabel["bob-user"].accountId, nativeAssetId, "100000"),
    balance(accountByLabel["validator-one"].accountId, nativeAssetId, "50000"),
    balance(accountByLabel["bridge-relayer"].accountId, nativeAssetId, "25000")
  ];
  const validatorSet = [
    authority(accountByLabel["validator-one"], "validator", "1", "1")
  ];
  const bridgePilotConfig = {
    enabled: true,
    sourceChainId: 8453,
    sourceNetwork: "base-mainnet-source-for-local-private-pilot",
    destinationProfile: "flowchain-base8453-pilot",
    lockboxAddress: addressFor("bridge-lockbox-base-8453"),
    releaseAuthorityAccountId: accountByLabel["bridge-release-authority"].accountId,
    relayerAccountId: accountByLabel["bridge-relayer"].accountId,
    duplicatePolicy: "reject_same_source_chain_lockbox_tx_hash_log_index",
    productionReady: false
  };
  const tokenDexBootstrapConfig = {
    nativeAssetId,
    localTokenLaunchAllowed: true,
    localTokenMintAllowed: true,
    dexBootstrapAllowed: true,
    defaultFeeBps: 30,
    productionReady: false
  };
  const genesisInput = {
    schema: GENESIS_INPUT_SCHEMA,
    protocolVersion: PROTOCOL_VERSION,
    networkProfile: profile.profileId,
    chainId: profile.chainId,
    networkName: profile.networkName,
    genesisTimestamp: "2026-05-13T15:00:00.000Z",
    genesisUnixMs: "1778684400000",
    stateRootSeed: hashJson("flowchain.production_l1.state_root_seed.v0", { profileId: profile.profileId, chainId: profile.chainId }),
    initialAccounts: accounts,
    initialBalances,
    validatorSet,
    bridgePilotConfig,
    tokenDexBootstrapConfig,
    productionReady: false
  };
  const genesis = buildGenesisFromInput(genesisInput);
  const bridgeEvidence = buildBridgeEvidence(genesis, accountByLabel, nativeAssetId);
  const transactionSet = buildTransactions(genesis, profile, accountByLabel, { nativeAssetId, tokenId, poolId, bridgeEvidence });
  const receiptsAndEvents = buildReceiptsAndEvents(transactionSet.transactions, bridgeEvidence);
  const stateRootManifest = buildStateRootManifest(genesis, transactionSet, receiptsAndEvents, bridgeEvidence, { nativeAssetId, tokenId, poolId });
  const block = buildBlock(genesis, profile, accountByLabel, transactionSet.transactions, receiptsAndEvents.receipts, receiptsAndEvents.events, bridgeEvidence, stateRootManifest);
  const finalityReceipt = buildFinalityReceipt(genesis, profile, accountByLabel, block);
  const exportSnapshot = buildExportSnapshot(genesis, block, stateRootManifest, finalityReceipt, { nativeAssetId, tokenId, poolId });
  const negativeFixtures = buildNegativeFixtures(genesis, profile, transactionSet.transactions, stateRootManifest, bridgeEvidence);
  return {
    profiles,
    genesisInput,
    genesis,
    transactions: transactionSet.transactions,
    receipts: receiptsAndEvents.receipts,
    events: receiptsAndEvents.events,
    bridgeEvidence,
    stateRootManifest,
    block,
    finalityReceipt,
    exportSnapshot,
    negativeFixtures
  };
}

function buildGenesisFromInput(input) {
  const initialAccountsRoot = hashJson("flowchain.production_l1.genesis_accounts_root.v0", input.initialAccounts);
  const initialBalancesRoot = hashJson("flowchain.production_l1.genesis_balances_root.v0", input.initialBalances);
  const validatorSetRoot = hashJson("flowchain.production_l1.genesis_validator_set_root.v0", input.validatorSet);
  const bridgePilotConfigHash = hashJson("flowchain.production_l1.bridge_pilot_config.v0", input.bridgePilotConfig);
  const tokenDexBootstrapConfigHash = hashJson("flowchain.production_l1.token_dex_bootstrap_config.v0", input.tokenDexBootstrapConfig);
  const genesisHashInput = {
    schema: "flowchain.production_l1.genesis_hash_input.v0",
    protocolVersion: input.protocolVersion,
    networkProfile: input.networkProfile,
    chainId: input.chainId,
    genesisTimestamp: input.genesisTimestamp,
    stateRootSeed: input.stateRootSeed,
    initialAccountsRoot,
    initialBalancesRoot,
    validatorSetRoot,
    bridgePilotConfigHash,
    tokenDexBootstrapConfigHash
  };
  return {
    schema: GENESIS_SCHEMA,
    protocolVersion: input.protocolVersion,
    networkProfile: input.networkProfile,
    chainId: input.chainId,
    networkName: input.networkName,
    genesisTimestamp: input.genesisTimestamp,
    genesisUnixMs: input.genesisUnixMs,
    stateRootSeed: input.stateRootSeed,
    initialAccounts: input.initialAccounts,
    initialBalances: input.initialBalances,
    validatorSet: input.validatorSet,
    bridgePilotConfig: input.bridgePilotConfig,
    tokenDexBootstrapConfig: input.tokenDexBootstrapConfig,
    genesisHashInput,
    genesisHash: hashJson("flowchain.production_l1.genesis_hash.v0", genesisHashInput),
    productionReady: false
  };
}

function buildAccounts(profile) {
  return [
    account("alice-user", profile, { user: true, validator: false, bridgeOperator: false, deployer: true, relayer: false, emergencyOperator: false }),
    account("bob-user", profile, { user: true, validator: false, bridgeOperator: false, deployer: false, relayer: false, emergencyOperator: false }),
    account("validator-one", profile, { user: false, validator: true, bridgeOperator: false, deployer: false, relayer: false, emergencyOperator: false }),
    account("bridge-relayer", profile, { user: false, validator: false, bridgeOperator: true, deployer: false, relayer: true, emergencyOperator: false }),
    account("bridge-release-authority", profile, { user: false, validator: false, bridgeOperator: true, deployer: false, relayer: false, emergencyOperator: false }),
    account("emergency-operator", profile, { user: false, validator: false, bridgeOperator: false, deployer: false, relayer: false, emergencyOperator: true })
  ];
}

function account(label, profile, roleFlags) {
  const publicKey = publicKeyFor(label);
  const accountId = hashJson("flowchain.production_l1.account_id.v0", { label, publicKey, chainId: profile.chainId, networkProfile: profile.profileId });
  return {
    schema: ACCOUNT_SCHEMA,
    accountId,
    label,
    publicKey,
    address: addressFor(`${label}:${profile.chainId}:${profile.profileId}`),
    addressDerivation: {
      algorithm: "keccak256(compressedSecp256k1PublicKey)[12:32]",
      preimageFields: ["publicKey", "chainId", "networkProfile"],
      chainIdBinding: true
    },
    nonceDomain: {
      domainId: hashJson("flowchain.production_l1.nonce_domain.v0", { accountId, chainId: profile.chainId, networkProfile: profile.profileId }),
      nextNonce: "1",
      replayScope: "chainId+networkProfile+genesisHash+accountId"
    },
    roleFlags,
    metadataHash: hashJson("flowchain.production_l1.account_metadata.v0", { label, roleFlags }),
    status: "active",
    productionReady: false
  };
}

function publicKeyFor(label) {
  return `0x02${hashJson("flowchain.production_l1.public_key_fixture.v0", { label }).slice(2)}`;
}

function addressFor(label) {
  return `0x${hashJson("flowchain.production_l1.address_fixture.v0", { label }).slice(-40)}`;
}

function balance(accountId, assetId, amount) {
  return { accountId, assetId, amount, balanceType: "native_local_unit", noValue: true };
}

function authority(account, authorityType, votingPower, finalityWeight) {
  return {
    schema: AUTHORITY_SCHEMA,
    authorityId: hashJson("flowchain.production_l1.authority_id.v0", { accountId: account.accountId, authorityType }),
    accountId: account.accountId,
    publicKey: account.publicKey,
    address: account.address,
    authorityType,
    votingPower,
    finalityWeight,
    metadataHash: hashJson("flowchain.production_l1.authority_metadata.v0", { accountId: account.accountId, authorityType }),
    status: "active",
    productionReady: false
  };
}

function buildBridgeEvidence(genesis, accounts, nativeAssetId) {
  const depositCore = {
    evidenceType: "deposit_observation",
    sourceChainId: 8453,
    sourceNetwork: "base-mainnet-source-for-local-private-pilot",
    lockboxAddress: genesis.bridgePilotConfig.lockboxAddress,
    sourceTxHash: hashJson("flowchain.production_l1.source_tx_hash.v0", { name: "base-deposit-1" }),
    sourceBlockNumber: "45960000",
    sourceLogIndex: 7,
    tokenAddress: addressFor("base-usdc-token"),
    assetId: nativeAssetId,
    depositorAddress: addressFor("base-depositor-alice"),
    localRecipientAccountId: accounts["bob-user"].accountId,
    amount: "2500000",
    observedByRelayerAccountId: accounts["bridge-relayer"].accountId,
    finalityStatus: "source_finalized"
  };
  const observationId = hashJson("flowchain.production_l1.bridge_observation_id.v0", sourceEventKey(depositCore));
  const creditId = hashJson("flowchain.production_l1.bridge_credit_id.v0", {
    observationId,
    localRecipientAccountId: depositCore.localRecipientAccountId,
    amount: depositCore.amount,
    assetId: depositCore.assetId
  });
  const deposit = finishBridgeEvidence({
    ...depositCore,
    observationId,
    creditId,
    release: null
  });

  const releaseCore = {
    evidenceType: "withdrawal_release",
    sourceChainId: 8453,
    sourceNetwork: "base-mainnet-source-for-local-private-pilot",
    lockboxAddress: genesis.bridgePilotConfig.lockboxAddress,
    sourceTxHash: hashJson("flowchain.production_l1.source_tx_hash.v0", { name: "base-release-1" }),
    sourceBlockNumber: "45960120",
    sourceLogIndex: 11,
    tokenAddress: addressFor("base-usdc-token"),
    assetId: nativeAssetId,
    depositorAddress: addressFor("base-lockbox-release"),
    localRecipientAccountId: accounts["bob-user"].accountId,
    amount: "100000",
    observedByRelayerAccountId: accounts["bridge-relayer"].accountId,
    finalityStatus: "source_finalized",
    release: {
      withdrawalIntentId: hashJson("flowchain.production_l1.withdrawal_intent_id.v0", { accountId: accounts["bob-user"].accountId, amount: "100000" }),
      releaseTxHash: hashJson("flowchain.production_l1.release_tx_hash.v0", { name: "base-release-1" }),
      releaseBlockNumber: "45960120",
      releaseLogIndex: 11,
      releasedToAddress: addressFor("base-withdrawal-recipient-bob"),
      releaseAuthorityAccountId: accounts["bridge-release-authority"].accountId
    }
  };
  const releaseObservationId = hashJson("flowchain.production_l1.bridge_observation_id.v0", sourceEventKey(releaseCore));
  const releaseCreditId = hashJson("flowchain.production_l1.bridge_credit_id.v0", {
    observationId: releaseObservationId,
    localRecipientAccountId: releaseCore.localRecipientAccountId,
    amount: releaseCore.amount,
    assetId: releaseCore.assetId
  });
  const release = finishBridgeEvidence({
    ...releaseCore,
    observationId: releaseObservationId,
    creditId: releaseCreditId
  });
  return [deposit, release];
}

function finishBridgeEvidence(evidence) {
  const duplicateKey = hashJson("flowchain.production_l1.bridge_duplicate_key.v0", sourceEventKey(evidence));
  const evidenceHash = hashJson("flowchain.production_l1.bridge_evidence_hash.v0", { ...evidence, duplicateKey });
  return {
    schema: BRIDGE_EVIDENCE_SCHEMA,
    evidenceId: hashJson("flowchain.production_l1.bridge_evidence_id.v0", { evidenceHash }),
    ...evidence,
    duplicateKey,
    evidenceHash,
    localOnly: true,
    productionReady: false
  };
}

function sourceEventKey(evidence) {
  return {
    sourceChainId: evidence.sourceChainId,
    lockboxAddress: evidence.lockboxAddress,
    sourceTxHash: evidence.sourceTxHash,
    sourceLogIndex: evidence.sourceLogIndex
  };
}

function buildTransactions(genesis, profile, accounts, ids) {
  const nonce = Object.fromEntries(Object.values(accounts).map((account) => [account.accountId, 1n]));
  const txs = [];
  const add = (label, role, payloadType, details, eventTypes, balanceChanges = []) => {
    const account = accounts[label];
    const current = nonce[account.accountId];
    const payload = makePayload(payloadType, account.accountId, current, details, eventTypes, balanceChanges);
    txs.push(makeEnvelope(genesis, profile, account, role, payload));
    nonce[account.accountId] = current + 1n;
  };

  add("alice-user", "user", "native_transfer", {
    fromAccountId: accounts["alice-user"].accountId,
    toAccountId: accounts["bob-user"].accountId,
    assetId: ids.nativeAssetId,
    amount: "10000",
    memoHash: hashJson("memo", "native-transfer")
  }, ["NativeTransferRecorded"], [
    { accountId: accounts["alice-user"].accountId, assetId: ids.nativeAssetId, delta: "-10000" },
    { accountId: accounts["bob-user"].accountId, assetId: ids.nativeAssetId, delta: "10000" }
  ]);
  add("alice-user", "deployer", "faucet_funding", {
    faucetId: hashJson("faucet", "bob-local-funding"),
    toAccountId: accounts["bob-user"].accountId,
    assetId: ids.nativeAssetId,
    amount: "5000",
    reasonHash: hashJson("reason", "local-test-funding"),
    localOnly: true
  }, ["FaucetFundingRecorded"], [
    { accountId: accounts["bob-user"].accountId, assetId: ids.nativeAssetId, delta: "5000" }
  ]);
  add("bridge-relayer", "relayer", "bridge_credit", {
    bridgeEvidenceId: ids.bridgeEvidence[0].evidenceId,
    observationId: ids.bridgeEvidence[0].observationId,
    creditId: ids.bridgeEvidence[0].creditId,
    sourceChainId: 8453,
    assetId: ids.nativeAssetId,
    amount: ids.bridgeEvidence[0].amount,
    recipientAccountId: accounts["bob-user"].accountId
  }, ["BridgeCreditApplied"], [
    { accountId: accounts["bob-user"].accountId, assetId: ids.nativeAssetId, delta: ids.bridgeEvidence[0].amount }
  ]);
  add("alice-user", "deployer", "token_launch", {
    tokenLaunchId: hashJson("token-launch", "FLOWT"),
    issuerAccountId: accounts["alice-user"].accountId,
    tokenId: ids.tokenId,
    symbol: "FLOWT",
    name: "FlowChain Local Test Token",
    decimals: 6,
    metadataHash: hashJson("token-metadata", "FLOWT"),
    initialSupply: "1000000000",
    recipientAccountId: accounts["alice-user"].accountId
  }, ["TokenLaunched"], [
    { accountId: accounts["alice-user"].accountId, assetId: ids.tokenId, delta: "1000000000" }
  ]);
  add("alice-user", "deployer", "token_mint", {
    mintId: hashJson("token-mint", "bob-FLOWT"),
    tokenId: ids.tokenId,
    toAccountId: accounts["bob-user"].accountId,
    amount: "250000",
    reasonHash: hashJson("mint-reason", "local-test-mode"),
    localOrTestMode: true
  }, ["TokenMinted"], [
    { accountId: accounts["bob-user"].accountId, assetId: ids.tokenId, delta: "250000" }
  ]);
  add("alice-user", "user", "token_transfer", {
    tokenTransferId: hashJson("token-transfer", "alice-to-bob-FLOWT"),
    tokenId: ids.tokenId,
    fromAccountId: accounts["alice-user"].accountId,
    toAccountId: accounts["bob-user"].accountId,
    amount: "50000",
    memoHash: hashJson("memo", "token-transfer")
  }, ["TokenTransferred"], [
    { accountId: accounts["alice-user"].accountId, assetId: ids.tokenId, delta: "-50000" },
    { accountId: accounts["bob-user"].accountId, assetId: ids.tokenId, delta: "50000" }
  ]);
  add("alice-user", "deployer", "pool_create", {
    poolCreateId: hashJson("pool-create", ids.poolId),
    creatorAccountId: accounts["alice-user"].accountId,
    poolId: ids.poolId,
    baseAssetId: ids.nativeAssetId,
    quoteAssetId: ids.tokenId,
    feeBps: 30,
    tickSpacing: 1,
    metadataHash: hashJson("pool-metadata", ids.poolId)
  }, ["PoolCreated"]);
  add("alice-user", "user", "add_liquidity", {
    liquidityId: hashJson("liquidity-add", ids.poolId),
    poolId: ids.poolId,
    providerAccountId: accounts["alice-user"].accountId,
    baseAmount: "100000",
    quoteAmount: "5000000",
    minLpUnits: "1"
  }, ["LiquidityAdded"], [
    { accountId: accounts["alice-user"].accountId, assetId: ids.nativeAssetId, delta: "-100000" },
    { accountId: accounts["alice-user"].accountId, assetId: ids.tokenId, delta: "-5000000" }
  ]);
  add("alice-user", "user", "remove_liquidity", {
    liquidityId: hashJson("liquidity-remove", ids.poolId),
    poolId: ids.poolId,
    providerAccountId: accounts["alice-user"].accountId,
    lpUnits: "100",
    minBaseAmount: "1",
    minQuoteAmount: "1"
  }, ["LiquidityRemoved"], [
    { accountId: accounts["alice-user"].accountId, assetId: ids.nativeAssetId, delta: "2000" },
    { accountId: accounts["alice-user"].accountId, assetId: ids.tokenId, delta: "100000" }
  ]);
  add("bob-user", "user", "swap", {
    swapId: hashJson("swap", "bob-native-to-FLOWT"),
    poolId: ids.poolId,
    traderAccountId: accounts["bob-user"].accountId,
    assetInId: ids.nativeAssetId,
    assetOutId: ids.tokenId,
    amountIn: "1000",
    minAmountOut: "40000",
    routeHash: hashJson("route", [ids.nativeAssetId, ids.tokenId])
  }, ["SwapExecuted"], [
    { accountId: accounts["bob-user"].accountId, assetId: ids.nativeAssetId, delta: "-1000" },
    { accountId: accounts["bob-user"].accountId, assetId: ids.tokenId, delta: "49000" }
  ]);
  add("bob-user", "user", "withdrawal_intent", {
    withdrawalIntentId: ids.bridgeEvidence[1].release.withdrawalIntentId,
    sourceAccountId: accounts["bob-user"].accountId,
    destinationChainId: 8453,
    destinationAddress: ids.bridgeEvidence[1].release.releasedToAddress,
    assetId: ids.nativeAssetId,
    amount: "100000",
    releasePolicyHash: hashJson("release-policy", "bridge-release-authority")
  }, ["WithdrawalIntentRecorded"], [
    { accountId: accounts["bob-user"].accountId, assetId: ids.nativeAssetId, delta: "-100000" }
  ]);
  add("validator-one", "validator", "validator_authority_config", {
    authorityConfigId: hashJson("authority-config", "validator-one"),
    authorityId: genesis.validatorSet[0].authorityId,
    validatorAccountId: accounts["validator-one"].accountId,
    action: "update",
    authorityType: "validator",
    votingPower: "1",
    metadataHash: hashJson("authority-metadata", "validator-one-update")
  }, ["ValidatorAuthorityConfigured"]);
  add("validator-one", "validator", "finality_vote", {
    voteId: hashJson("finality-vote", "height-1"),
    validatorAccountId: accounts["validator-one"].accountId,
    height: "1",
    blockHash: hashJson("pre-final-block-hash", "height-1"),
    stateRoot: hashJson("pre-final-state-root", "height-1"),
    voteRound: "1"
  }, ["FinalityVoteRecorded"]);
  add("validator-one", "validator", "finality_certificate", {
    certificateId: hashJson("finality-certificate", "height-1"),
    height: "1",
    blockHash: hashJson("pre-final-block-hash", "height-1"),
    stateRoot: hashJson("pre-final-state-root", "height-1"),
    signerSetRoot: hashJson("validator-set", genesis.validatorSet),
    voteIds: [hashJson("finality-vote", "height-1")],
    quorumNumerator: 1,
    quorumDenominator: 1
  }, ["FinalityCertificateRecorded"]);

  for (const payloadType of OBJECT_PAYLOAD_TYPES) {
    const objectType = objectTypeForPayload(payloadType);
    add("alice-user", "deployer", payloadType, {
      lifecycleUpdateId: hashJson("lifecycle", payloadType),
      objectType,
      operation: objectType === "FinalityReceipt" ? "finalize" : "create",
      objectId: hashJson("object-id", objectType),
      objectHash: hashJson("object-hash", objectType),
      status: objectType === "Challenge" ? "resolved" : objectType === "FinalityReceipt" ? "finalized" : "active",
      rootfieldId: hashJson("rootfield", "flowchain-local-core"),
      sourceReceiptId: hashJson("source-receipt", objectType),
      parentObjectId: null
    }, ["ObjectLifecycleUpdated"]);
  }

  return { transactions: txs };
}

function makePayload(payloadType, actorAccountId, nonce, details, emittedEventTypes, balanceChanges) {
  const payloadId = hashJson("flowchain.production_l1.payload_id.v0", { payloadType, actorAccountId, nonce: nonce.toString(), details });
  return {
    schema: PAYLOAD_SCHEMA,
    payloadType,
    payloadId,
    actorAccountId,
    accountNonce: nonce.toString(),
    details,
    preconditions: [`payload_type:${payloadType}`, `account_nonce:${nonce.toString()}`],
    stateWrites: [`${payloadType}:state_write:${payloadId}`],
    balanceChanges,
    nonceChange: {
      accountId: actorAccountId,
      before: nonce.toString(),
      after: (nonce + 1n).toString()
    },
    emittedEventTypes,
    indexKeys: [
      { key: "payloadType", value: payloadType },
      { key: "actorAccountId", value: actorAccountId }
    ],
    localOnly: true,
    productionReady: false
  };
}

function makeEnvelope(genesis, profile, account, role, payload) {
  const payloadHash = hashJson("flowchain.production_l1.payload_hash.v0", payload);
  const signingDigestInput = {
    protocolVersion: PROTOCOL_VERSION,
    chainId: profile.chainId,
    networkProfile: profile.profileId,
    genesisHash: genesis.genesisHash,
    nonce: payload.accountNonce,
    signerAccountId: account.accountId,
    payloadType: payload.payloadType,
    payloadHash
  };
  const signingDigest = hashJson("flowchain.production_l1.signing_digest.v0", signingDigestInput);
  const txIdInput = {
    chainId: profile.chainId,
    networkProfile: profile.profileId,
    genesisHash: genesis.genesisHash,
    nonce: payload.accountNonce,
    signerAccountId: account.accountId,
    payloadType: payload.payloadType,
    payloadHash
  };
  return {
    schema: ENVELOPE_SCHEMA,
    txId: hashJson("flowchain.production_l1.tx_id.v0", txIdInput),
    protocolVersion: PROTOCOL_VERSION,
    chainId: profile.chainId,
    networkProfile: profile.profileId,
    genesisHash: genesis.genesisHash,
    nonce: payload.accountNonce,
    nonceDomain: account.nonceDomain.domainId,
    signer: {
      accountId: account.accountId,
      publicKey: account.publicKey,
      address: account.address,
      role
    },
    payloadType: payload.payloadType,
    payloadHash,
    payload,
    fee: {
      mode: "local_gas_units",
      gasLimit: "1000000",
      maxFeePerGas: "0",
      localExecutionCostLimit: "1000000"
    },
    expiration: {
      validAfterBlock: "0",
      validUntilBlock: "100",
      expiresAtUnixMs: "1778691600000"
    },
    signature: {
      scheme: "fixture-secp256k1-digest-only",
      signingDigest,
      value: `0x${signingDigest.slice(2)}${hashJson("flowchain.production_l1.signature_tail.v0", signingDigest).slice(2)}`
    }
  };
}

function buildReceiptsAndEvents(transactions, bridgeEvidence) {
  const receipts = [];
  const events = [];
  for (const tx of transactions) {
    const receiptIdInput = hashJson("flowchain.production_l1.receipt_id_input.v0", { txId: tx.txId, payloadType: tx.payloadType, status: "succeeded" });
    const receiptId = hashJson("flowchain.production_l1.receipt_id.v0", { receiptIdInput });
    const txEvents = tx.payload.emittedEventTypes.map((eventType, index) => {
      const deterministicIdInput = hashJson("flowchain.production_l1.event_id_input.v0", { txId: tx.txId, receiptId, eventType, index });
      return {
        schema: EVENT_SCHEMA,
        eventId: hashJson("flowchain.production_l1.event_id.v0", { deterministicIdInput }),
        eventType,
        payloadType: tx.payloadType,
        txId: tx.txId,
        receiptId,
        blockHeight: "1",
        eventIndex: events.length + index,
        emitterAccountId: tx.signer.accountId,
        subjectId: subjectIdForPayload(tx.payload),
        attributes: [
          { key: "payloadType", value: tx.payloadType, valueType: "string" },
          { key: "payloadId", value: tx.payload.payloadId, valueType: "hex32" }
        ],
        deterministicIdInput
      };
    });
    events.push(...txEvents);
    const evidenceRefs = tx.payloadType === "bridge_credit" ? [bridgeEvidence[0].evidenceId] : tx.payloadType === "withdrawal_intent" ? [bridgeEvidence[1].evidenceId] : [];
    receipts.push({
      schema: RECEIPT_SCHEMA,
      receiptId,
      txId: tx.txId,
      payloadType: tx.payloadType,
      status: "succeeded",
      executionCost: {
        costUnits: (1000 + receipts.length * 10).toString(),
        meter: "local_execution_units"
      },
      stateDeltaRef: hashJson("flowchain.production_l1.state_delta_ref.v0", { txId: tx.txId, payloadType: tx.payloadType }),
      emittedEvents: txEvents.map((event) => event.eventId),
      bridgeEvidenceRefs: evidenceRefs,
      errorCode: null,
      failureReason: null,
      deterministicIdInput: receiptIdInput
    });
  }
  return { receipts, events };
}

function subjectIdForPayload(payload) {
  const details = payload.details;
  return details.tokenId ?? details.poolId ?? details.creditId ?? details.withdrawalIntentId ?? details.objectId ?? details.authorityId ?? payload.payloadId;
}

function buildStateRootManifest(genesis, transactionSet, receiptsAndEvents, bridgeEvidence, ids) {
  const stateComponents = {
    accounts: genesis.initialAccounts,
    balances: [
      ...genesis.initialBalances,
      { accountId: genesis.initialAccounts[1].accountId, assetId: ids.nativeAssetId, amount: "2640000", balanceType: "native_local_unit", noValue: true },
      { accountId: genesis.initialAccounts[0].accountId, assetId: ids.tokenId, amount: "995050000", balanceType: "test_token", noValue: true },
      { accountId: genesis.initialAccounts[1].accountId, assetId: ids.tokenId, amount: "349000", balanceType: "test_token", noValue: true }
    ],
    tokens: [
      { tokenId: ids.tokenId, symbol: "FLOWT", name: "FlowChain Local Test Token", decimals: 6, totalSupply: "1000250000", noValue: true }
    ],
    pools: [
      { poolId: ids.poolId, baseAssetId: ids.nativeAssetId, quoteAssetId: ids.tokenId, reserveBase: "99000", reserveQuote: "4951000", feeBps: 30, noValue: true }
    ],
    lp_positions: [
      { lpPositionId: hashJson("lp-position", ids.poolId), poolId: ids.poolId, ownerAccountId: genesis.initialAccounts[0].accountId, lpUnits: "99900", noValue: true }
    ],
    bridge_credits: [
      { creditId: bridgeEvidence[0].creditId, observationId: bridgeEvidence[0].observationId, accountId: bridgeEvidence[0].localRecipientAccountId, amount: bridgeEvidence[0].amount, assetId: bridgeEvidence[0].assetId }
    ],
    withdrawals: [
      { withdrawalIntentId: bridgeEvidence[1].release.withdrawalIntentId, accountId: bridgeEvidence[1].localRecipientAccountId, amount: bridgeEvidence[1].amount, assetId: bridgeEvidence[1].assetId, releaseEvidenceId: bridgeEvidence[1].evidenceId }
    ],
    object_store: transactionSet.transactions
      .filter((tx) => OBJECT_PAYLOAD_TYPES.includes(tx.payloadType))
      .map((tx) => ({
        objectType: tx.payload.details.objectType,
        objectId: tx.payload.details.objectId,
        objectHash: tx.payload.details.objectHash,
        status: tx.payload.details.status
      })),
    finality: [
      { height: "1", status: "accepted", certificateId: hashJson("finality-certificate", "height-1") }
    ],
    validator_state: genesis.validatorSet
  };
  const components = STATE_COMPONENTS.map((component) => {
    const entries = stateComponents[component];
    return {
      component,
      root: hashJson("flowchain.production_l1.state_component_root.v0", { component, entries }),
      count: entries.length,
      ownerAgent: ownerForStateComponent(component),
      inputs: stateInputsForComponent(component)
    };
  });
  const stateRoot = hashJson("flowchain.production_l1.state_root.v0", {
    chainId: genesis.chainId,
    networkProfile: genesis.networkProfile,
    genesisHash: genesis.genesisHash,
    components: components.map(({ component, root, count }) => ({ component, root, count }))
  });
  return {
    schema: STATE_ROOT_SCHEMA,
    chainId: genesis.chainId,
    networkProfile: genesis.networkProfile,
    genesisHash: genesis.genesisHash,
    stateRoot,
    stateRootAlgorithm: "keccak256(canonical-json-sorted-keys-v0)",
    components,
    stateComponents,
    deterministicReplay: {
      sameLogicalStateRoot: stateRoot,
      replayCommand: "npm run validate:production-l1-fixtures"
    }
  };
}

function ownerForStateComponent(component) {
  if (component === "bridge_credits" || component === "withdrawals") return "bridge";
  if (component === "validator_state" || component === "finality") return "consensus";
  if (component === "accounts") return "wallet";
  return "runtime";
}

function stateInputsForComponent(component) {
  const inputs = {
    accounts: ["accountId", "publicKey", "address", "roleFlags", "nonceDomain"],
    balances: ["accountId", "assetId", "amount"],
    tokens: ["tokenId", "symbol", "decimals", "totalSupply"],
    pools: ["poolId", "baseAssetId", "quoteAssetId", "reserves"],
    lp_positions: ["lpPositionId", "poolId", "ownerAccountId", "lpUnits"],
    bridge_credits: ["creditId", "observationId", "accountId", "assetId", "amount"],
    withdrawals: ["withdrawalIntentId", "accountId", "assetId", "amount", "releaseEvidenceId"],
    object_store: ["objectType", "objectId", "objectHash", "status"],
    finality: ["height", "status", "certificateId"],
    validator_state: ["authorityId", "accountId", "votingPower", "status"]
  };
  return inputs[component];
}

function buildBlock(genesis, profile, accounts, transactions, receipts, events, bridgeEvidence, stateRootManifest) {
  const txRoot = hashJson("flowchain.production_l1.tx_root.v0", transactions.map((tx) => tx.txId));
  const receiptRoot = hashJson("flowchain.production_l1.receipt_root.v0", receipts.map((receipt) => receipt.receiptId));
  const eventRoot = hashJson("flowchain.production_l1.event_root.v0", events.map((event) => event.eventId));
  const evidenceRoot = hashJson("flowchain.production_l1.evidence_root.v0", bridgeEvidence.map((evidence) => evidence.evidenceId));
  const headerBase = {
    schema: BLOCK_HEADER_SCHEMA,
    chainId: genesis.chainId,
    networkProfile: genesis.networkProfile,
    genesisHash: genesis.genesisHash,
    height: "1",
    parentHash: ZERO_HASH,
    timestamp: "2026-05-13T15:00:02.000Z",
    proposer: accounts["validator-one"].accountId,
    txRoot,
    receiptRoot,
    eventRoot,
    stateRoot: stateRootManifest.stateRoot,
    evidenceRoot,
    finalizedHeight: "0",
    protocolVersion: profile ? PROTOCOL_VERSION : PROTOCOL_VERSION
  };
  const header = {
    ...headerBase,
    blockHash: hashJson("flowchain.production_l1.block_hash.v0", headerBase)
  };
  return {
    schema: BLOCK_BODY_SCHEMA,
    header,
    transactions,
    receipts,
    events,
    bridgeEvidence,
    stateRootManifest
  };
}

function buildFinalityReceipt(genesis, profile, accounts, block) {
  const certificateHash = hashJson("flowchain.production_l1.finality_certificate_hash.v0", {
    blockHash: block.header.blockHash,
    stateRoot: block.header.stateRoot,
    validatorSet: genesis.validatorSet
  });
  return {
    schema: FINALITY_SCHEMA,
    finalityReceiptId: hashJson("flowchain.production_l1.finality_receipt_id.v0", { blockHash: block.header.blockHash, certificateHash }),
    chainId: genesis.chainId,
    networkProfile: genesis.networkProfile,
    height: block.header.height,
    blockHash: block.header.blockHash,
    stateRoot: block.header.stateRoot,
    finalizedHeight: block.header.height,
    finalityRule: profile.finalityRule.rule,
    status: "accepted",
    validatorSetHash: hashJson("flowchain.production_l1.validator_set_hash.v0", genesis.validatorSet),
    certificateHash,
    evidenceRoot: block.header.evidenceRoot,
    producedAt: "2026-05-13T15:00:03.000Z",
    productionReady: false
  };
}

function buildExportSnapshot(genesis, block, stateRootManifest, finalityReceipt, ids) {
  return {
    schema: EXPORT_SNAPSHOT_SCHEMA,
    chainId: genesis.chainId,
    networkProfile: genesis.networkProfile,
    genesisHash: genesis.genesisHash,
    blockHeight: block.header.height,
    blockHash: block.header.blockHash,
    stateRoot: block.header.stateRoot,
    stateRootManifest,
    accounts: genesis.initialAccounts,
    balances: stateRootManifest.stateComponents.balances,
    tokens: stateRootManifest.stateComponents.tokens,
    pools: stateRootManifest.stateComponents.pools,
    bridgeCredits: stateRootManifest.stateComponents.bridge_credits,
    withdrawals: stateRootManifest.stateComponents.withdrawals,
    objectStoreRefs: stateRootManifest.stateComponents.object_store,
    finalityReceipts: [finalityReceipt],
    provenance: {
      generatedBy: "fixtures/production-l1/production-l1-tools.mjs",
      schemaNames: Object.keys(buildSchemas()).sort(),
      fixturePaths: [
        "fixtures/production-l1/profiles.json",
        "fixtures/production-l1/genesis.input.json",
        "fixtures/production-l1/genesis.json",
        "fixtures/production-l1/transactions.valid.json",
        "fixtures/production-l1/receipts.valid.json",
        "fixtures/production-l1/block.valid.json",
        "fixtures/production-l1/negative-fixtures.json"
      ],
      validationCommands: [
        "npm run validate:production-l1-protocol",
        "npm run validate:production-l1-fixtures"
      ]
    },
    productionReady: false
  };
}

function buildNegativeFixtures(genesis, profile, transactions, stateRootManifest, bridgeEvidence) {
  const malformedByType = transactions.map((tx) => ({
    caseId: `invalid_${tx.payloadType}_malformed_payload_hash`,
    fixtureKind: "transaction",
    expectedErrorCode: ERROR_CODES.MALFORMED_PAYLOAD_HASH,
    transaction: { ...tx, payloadHash: flipHash(tx.payloadHash) }
  }));
  return {
    schema: "flowchain.production_l1.negative_fixture_set.v0",
    cases: [
      {
        caseId: "wrong_chain_transaction",
        fixtureKind: "transaction",
        expectedErrorCode: ERROR_CODES.WRONG_CHAIN,
        transaction: { ...transactions[0], chainId: "742999" }
      },
      {
        caseId: "wrong_genesis_hash_transaction",
        fixtureKind: "transaction",
        expectedErrorCode: ERROR_CODES.WRONG_GENESIS,
        transaction: { ...transactions[0], genesisHash: hashJson("wrong", "genesis") }
      },
      {
        caseId: "stale_nonce_transaction",
        fixtureKind: "transaction",
        expectedErrorCode: ERROR_CODES.STALE_NONCE,
        expectedNonce: "5",
        transaction: recomputeEnvelope({ ...transactions[0], nonce: "1" })
      },
      {
        caseId: "duplicate_tx_transaction_set",
        fixtureKind: "transaction_set",
        expectedErrorCode: ERROR_CODES.DUPLICATE_TX,
        transactions: [transactions[0], transactions[0]]
      },
      {
        caseId: "malformed_payload_hash_transaction",
        fixtureKind: "transaction",
        expectedErrorCode: ERROR_CODES.MALFORMED_PAYLOAD_HASH,
        transaction: { ...transactions[0], payloadHash: flipHash(transactions[0].payloadHash) }
      },
      {
        caseId: "malformed_state_root_manifest",
        fixtureKind: "state_root_manifest",
        expectedErrorCode: ERROR_CODES.MALFORMED_STATE_ROOT,
        stateRootManifest: { ...stateRootManifest, stateRoot: ZERO_HASH }
      },
      {
        caseId: "invalid_bridge_source_chain",
        fixtureKind: "bridge_evidence",
        expectedErrorCode: ERROR_CODES.INVALID_BRIDGE_SOURCE_CHAIN,
        bridgeEvidence: { ...bridgeEvidence[0], sourceChainId: 1 }
      },
      {
        caseId: "duplicate_bridge_event",
        fixtureKind: "bridge_evidence_set",
        expectedErrorCode: ERROR_CODES.DUPLICATE_BRIDGE_EVENT,
        bridgeEvidence: [
          bridgeEvidence[0],
          {
            ...bridgeEvidence[0],
            evidenceId: hashJson("duplicate-evidence-id", bridgeEvidence[0].evidenceId)
          }
        ]
      },
      ...malformedByType
    ]
  };
}

function recomputeEnvelope(tx) {
  const payloadHash = tx.payloadHash;
  const signingDigestInput = {
    protocolVersion: tx.protocolVersion,
    chainId: tx.chainId,
    networkProfile: tx.networkProfile,
    genesisHash: tx.genesisHash,
    nonce: tx.nonce,
    signerAccountId: tx.signer.accountId,
    payloadType: tx.payloadType,
    payloadHash
  };
  const signingDigest = hashJson("flowchain.production_l1.signing_digest.v0", signingDigestInput);
  const txIdInput = {
    chainId: tx.chainId,
    networkProfile: tx.networkProfile,
    genesisHash: tx.genesisHash,
    nonce: tx.nonce,
    signerAccountId: tx.signer.accountId,
    payloadType: tx.payloadType,
    payloadHash
  };
  return {
    ...tx,
    txId: hashJson("flowchain.production_l1.tx_id.v0", txIdInput),
    signature: {
      ...tx.signature,
      signingDigest,
      value: `0x${signingDigest.slice(2)}${hashJson("flowchain.production_l1.signature_tail.v0", signingDigest).slice(2)}`
    }
  };
}

function flipHash(hash) {
  return `${hash.slice(0, -1)}${hash.endsWith("0") ? "1" : "0"}`;
}

function objectTypeForPayload(payloadType) {
  const map = {
    agent_account_update: "AgentAccount",
    model_passport_update: "ModelPassport",
    work_receipt_update: "WorkReceipt",
    artifact_availability_proof_update: "ArtifactAvailabilityProof",
    verifier_module_update: "VerifierModule",
    verifier_report_update: "VerifierReport",
    memory_cell_update: "MemoryCell",
    challenge_update: "Challenge",
    finality_receipt_update: "FinalityReceipt"
  };
  return map[payloadType];
}

function payloadOwner(payloadType) {
  if (payloadType.includes("bridge") || payloadType === "withdrawal_intent") return "bridge";
  if (payloadType.includes("finality") || payloadType.includes("validator")) return "consensus";
  if (OBJECT_PAYLOAD_TYPES.includes(payloadType)) return "runtime";
  return "runtime";
}

function schemaPaths() {
  return Object.keys(buildSchemas()).sort().map((name) => resolve(schemasDir, name));
}

function fixturePaths() {
  return [
    "profiles.json",
    "genesis.input.json",
    "genesis.json",
    "transactions.valid.json",
    "receipts.valid.json",
    "events.valid.json",
    "bridge-evidence.valid.json",
    "state-root-manifest.valid.json",
    "block.valid.json",
    "finality-receipt.valid.json",
    "export-snapshot.valid.json",
    "negative-fixtures.json"
  ].map((name) => resolve(fixturesDir, name));
}

function writeSchemasAndFixtures() {
  const schemas = buildSchemas();
  mkdirSync(schemasDir, { recursive: true });
  for (const [name, schema] of Object.entries(schemas)) {
    writeJson(resolve(schemasDir, name), schema);
  }
  const all = buildAll();
  writeJson(resolve(fixturesDir, "profiles.json"), { schema: "flowchain.production_l1.network_profile_set.v0", profiles: all.profiles });
  writeJson(resolve(fixturesDir, "genesis.input.json"), all.genesisInput);
  writeJson(resolve(fixturesDir, "genesis.json"), all.genesis);
  writeJson(resolve(fixturesDir, "transactions.valid.json"), { schema: "flowchain.production_l1.transaction_fixture_set.v0", transactions: all.transactions });
  writeJson(resolve(fixturesDir, "receipts.valid.json"), { schema: "flowchain.production_l1.receipt_fixture_set.v0", receipts: all.receipts });
  writeJson(resolve(fixturesDir, "events.valid.json"), { schema: "flowchain.production_l1.event_fixture_set.v0", events: all.events });
  writeJson(resolve(fixturesDir, "bridge-evidence.valid.json"), { schema: "flowchain.production_l1.bridge_evidence_fixture_set.v0", bridgeEvidence: all.bridgeEvidence });
  writeJson(resolve(fixturesDir, "state-root-manifest.valid.json"), all.stateRootManifest);
  writeJson(resolve(fixturesDir, "block.valid.json"), all.block);
  writeJson(resolve(fixturesDir, "finality-receipt.valid.json"), all.finalityReceipt);
  writeJson(resolve(fixturesDir, "export-snapshot.valid.json"), all.exportSnapshot);
  writeJson(resolve(fixturesDir, "negative-fixtures.json"), all.negativeFixtures);
  return all;
}

async function validateProtocol() {
  assertKeccak();
  const missing = schemaPaths().filter((path) => !existsSync(path));
  if (missing.length > 0) {
    throw new Error(`missing required schema files: ${missing.join(", ")}`);
  }
  const { ajv } = await compileAjv();
  const schemas = buildSchemas();
  for (const [name, schema] of Object.entries(schemas)) {
    const disk = readJson(resolve(schemasDir, name));
    if (canonicalJson(disk) !== canonicalJson(schema)) {
      throw new Error(`schema drift: ${name}; run node fixtures/production-l1/production-l1-tools.mjs write`);
    }
    if (!ajv.getSchema(disk.$id)) {
      throw new Error(`schema did not compile: ${name}`);
    }
  }
  const profileSet = readJson(resolve(fixturesDir, "profiles.json"));
  const profiles = profileSet.profiles ?? [];
  assertEqualSets(profiles.map((profile) => profile.profileId), PROFILE_IDS, "profile ids");
  for (const profile of profiles) {
    validateWithAjv(ajv, "production-network-profile.schema.json", profile, `profile ${profile.profileId}`);
    assertEqualSets(profile.allowedTransactionFamilies, PAYLOAD_TYPES, `${profile.profileId} transaction families`);
  }
  return {
    schemas: Object.keys(schemas).length,
    profiles: profiles.length,
    payloadTypes: PAYLOAD_TYPES.length
  };
}

async function validateFixtures() {
  assertKeccak();
  const { ajv } = await compileAjv();
  const profileSet = readJson(resolve(fixturesDir, "profiles.json"));
  const profiles = profileSet.profiles;
  const profile = profiles.find((entry) => entry.profileId === "flowchain-base8453-pilot");
  const genesisInput = readJson(resolve(fixturesDir, "genesis.input.json"));
  const genesis = readJson(resolve(fixturesDir, "genesis.json"));
  const transactions = readJson(resolve(fixturesDir, "transactions.valid.json")).transactions;
  const receipts = readJson(resolve(fixturesDir, "receipts.valid.json")).receipts;
  const events = readJson(resolve(fixturesDir, "events.valid.json")).events;
  const bridgeEvidence = readJson(resolve(fixturesDir, "bridge-evidence.valid.json")).bridgeEvidence;
  const stateRootManifest = readJson(resolve(fixturesDir, "state-root-manifest.valid.json"));
  const block = readJson(resolve(fixturesDir, "block.valid.json"));
  const finalityReceipt = readJson(resolve(fixturesDir, "finality-receipt.valid.json"));
  const exportSnapshot = readJson(resolve(fixturesDir, "export-snapshot.valid.json"));
  const negativeFixtures = readJson(resolve(fixturesDir, "negative-fixtures.json"));

  const rebuilt = buildAll();
  const fixtureComparisons = [
    ["profiles.json", { schema: "flowchain.production_l1.network_profile_set.v0", profiles: rebuilt.profiles }, profileSet],
    ["genesis.input.json", rebuilt.genesisInput, genesisInput],
    ["genesis.json", rebuilt.genesis, genesis],
    ["transactions.valid.json", { schema: "flowchain.production_l1.transaction_fixture_set.v0", transactions: rebuilt.transactions }, readJson(resolve(fixturesDir, "transactions.valid.json"))],
    ["receipts.valid.json", { schema: "flowchain.production_l1.receipt_fixture_set.v0", receipts: rebuilt.receipts }, readJson(resolve(fixturesDir, "receipts.valid.json"))],
    ["events.valid.json", { schema: "flowchain.production_l1.event_fixture_set.v0", events: rebuilt.events }, readJson(resolve(fixturesDir, "events.valid.json"))],
    ["bridge-evidence.valid.json", { schema: "flowchain.production_l1.bridge_evidence_fixture_set.v0", bridgeEvidence: rebuilt.bridgeEvidence }, readJson(resolve(fixturesDir, "bridge-evidence.valid.json"))],
    ["state-root-manifest.valid.json", rebuilt.stateRootManifest, stateRootManifest],
    ["block.valid.json", rebuilt.block, block],
    ["finality-receipt.valid.json", rebuilt.finalityReceipt, finalityReceipt],
    ["export-snapshot.valid.json", rebuilt.exportSnapshot, exportSnapshot],
    ["negative-fixtures.json", rebuilt.negativeFixtures, negativeFixtures]
  ];
  for (const [name, expected, actual] of fixtureComparisons) {
    if (canonicalJson(expected) !== canonicalJson(actual)) {
      throw new Error(`fixture drift: ${name}; run node fixtures/production-l1/production-l1-tools.mjs write`);
    }
  }

  for (const profileEntry of profiles) validateWithAjv(ajv, "production-network-profile.schema.json", profileEntry, `profile ${profileEntry.profileId}`);
  validateWithAjv(ajv, "production-genesis.schema.json", genesis, "genesis");
  for (const account of genesis.initialAccounts) validateWithAjv(ajv, "production-account-public-metadata.schema.json", account, `account ${account.label}`);
  for (const authorityEntry of genesis.validatorSet) validateWithAjv(ajv, "production-validator-authority.schema.json", authorityEntry, `authority ${authorityEntry.authorityId}`);
  for (const tx of transactions) {
    validateWithAjv(ajv, "production-transaction-payload.schema.json", tx.payload, `payload ${tx.payloadType}`);
    validateWithAjv(ajv, "production-transaction-envelope.schema.json", tx, `tx ${tx.txId}`);
  }
  for (const receipt of receipts) validateWithAjv(ajv, "production-receipt.schema.json", receipt, `receipt ${receipt.receiptId}`);
  for (const event of events) validateWithAjv(ajv, "production-event.schema.json", event, `event ${event.eventId}`);
  for (const evidence of bridgeEvidence) validateWithAjv(ajv, "production-bridge-evidence.schema.json", evidence, `bridge evidence ${evidence.evidenceId}`);
  validateWithAjv(ajv, "production-state-root-manifest.schema.json", stateRootManifest, "state root manifest");
  validateWithAjv(ajv, "production-block-body.schema.json", block, "block");
  validateWithAjv(ajv, "production-finality-receipt.schema.json", finalityReceipt, "finality receipt");
  validateWithAjv(ajv, "production-export-snapshot.schema.json", exportSnapshot, "export snapshot");

  validateGenesisHash(genesisInput, genesis);
  validateTransactionSet(transactions, genesis, profile);
  validateReceiptsAndEvents(receipts, events, transactions);
  validateBridgeEvidenceSet(bridgeEvidence, profile);
  validateStateRootManifest(stateRootManifest);
  validateBlock(block, transactions, receipts, events, bridgeEvidence, stateRootManifest);
  validateFinalityReceipt(finalityReceipt, block, profile);
  validateNegativeFixtures(negativeFixtures, genesis, profile);

  assertEqualSets([...new Set(transactions.map((tx) => tx.payloadType))], PAYLOAD_TYPES, "valid transaction payload type coverage");
  const invalidTypes = negativeFixtures.cases
    .filter((entry) => entry.caseId.startsWith("invalid_") && entry.caseId.endsWith("_malformed_payload_hash"))
    .map((entry) => entry.transaction.payloadType);
  assertEqualSets([...new Set(invalidTypes)], PAYLOAD_TYPES, "invalid transaction payload type coverage");

  return {
    profiles: profiles.length,
    transactions: transactions.length,
    receipts: receipts.length,
    events: events.length,
    bridgeEvidence: bridgeEvidence.length,
    negativeCases: negativeFixtures.cases.length,
    stateRoot: stateRootManifest.stateRoot,
    genesisHash: genesis.genesisHash
  };
}

async function compileAjv() {
  const Ajv2020 = (await import("ajv/dist/2020.js")).default;
  const addFormats = (await import("ajv-formats")).default;
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  for (const path of schemaPaths()) {
    if (existsSync(path)) {
      ajv.addSchema(readJson(path));
    }
  }
  return { ajv };
}

function validateWithAjv(ajv, schemaName, value, label) {
  const validate = ajv.getSchema(`https://flowmemory.local/schemas/flowmemory/${schemaName}`);
  if (!validate) throw new Error(`missing compiled schema: ${schemaName}`);
  if (!validate(value)) {
    throw new Error(`${label} failed ${schemaName}: ${ajv.errorsText(validate.errors)}`);
  }
}

function validateGenesisHash(input, genesis) {
  const rebuilt = buildGenesisFromInput(input);
  if (rebuilt.genesisHash !== genesis.genesisHash) {
    throw new Error(`genesis hash mismatch: expected ${rebuilt.genesisHash}, got ${genesis.genesisHash}`);
  }
}

function validateTransactionSet(transactions, genesis, profile) {
  const seen = new Set();
  const accountMap = Object.fromEntries(genesis.initialAccounts.map((account) => [account.accountId, account]));
  for (const tx of transactions) {
    const error = validateTransaction(tx, genesis, profile, accountMap);
    if (error) throw new Error(`${tx.txId} failed semantic validation: ${error}`);
    if (seen.has(tx.txId)) throw new Error(`${ERROR_CODES.DUPLICATE_TX}: ${tx.txId}`);
    seen.add(tx.txId);
  }
}

function validateTransaction(tx, genesis, profile, accountMap, options = {}) {
  if (tx.chainId !== profile.chainId) return ERROR_CODES.WRONG_CHAIN;
  if (tx.networkProfile !== profile.profileId) return ERROR_CODES.WRONG_PROFILE;
  if (tx.genesisHash !== genesis.genesisHash) return ERROR_CODES.WRONG_GENESIS;
  if (options.expectedNonce && BigInt(tx.nonce) < BigInt(options.expectedNonce)) return ERROR_CODES.STALE_NONCE;
  if (!profile.allowedTransactionFamilies.includes(tx.payloadType)) return ERROR_CODES.WRONG_PROFILE;
  if (tx.payload.payloadType !== tx.payloadType) return ERROR_CODES.MALFORMED_PAYLOAD_HASH;
  const payloadHash = hashJson("flowchain.production_l1.payload_hash.v0", tx.payload);
  if (tx.payloadHash !== payloadHash) return ERROR_CODES.MALFORMED_PAYLOAD_HASH;
  const txId = hashJson("flowchain.production_l1.tx_id.v0", {
    chainId: tx.chainId,
    networkProfile: tx.networkProfile,
    genesisHash: tx.genesisHash,
    nonce: tx.nonce,
    signerAccountId: tx.signer.accountId,
    payloadType: tx.payloadType,
    payloadHash: tx.payloadHash
  });
  if (tx.txId !== txId) return ERROR_CODES.MALFORMED_TX_ID;
  const account = accountMap?.[tx.signer.accountId];
  if (account && (account.publicKey !== tx.signer.publicKey || account.address !== tx.signer.address)) {
    return ERROR_CODES.MALFORMED_TX_ID;
  }
  return null;
}

function validateReceiptsAndEvents(receipts, events, transactions) {
  const txIds = new Set(transactions.map((tx) => tx.txId));
  const eventIds = new Set(events.map((event) => event.eventId));
  for (const receipt of receipts) {
    if (!txIds.has(receipt.txId)) throw new Error(`receipt references unknown tx: ${receipt.receiptId}`);
    for (const eventId of receipt.emittedEvents) {
      if (!eventIds.has(eventId)) throw new Error(`receipt references unknown event: ${receipt.receiptId} ${eventId}`);
    }
  }
}

function validateBridgeEvidenceSet(bridgeEvidence, profile) {
  const seen = new Set();
  for (const evidence of bridgeEvidence) {
    if (!profile.allowedBridgeSourceChainIds.includes(evidence.sourceChainId)) {
      throw new Error(`${ERROR_CODES.INVALID_BRIDGE_SOURCE_CHAIN}: ${evidence.evidenceId}`);
    }
    const key = canonicalJson(sourceEventKey(evidence));
    if (seen.has(key)) throw new Error(`${ERROR_CODES.DUPLICATE_BRIDGE_EVENT}: ${evidence.evidenceId}`);
    seen.add(key);
  }
}

function validateStateRootManifest(manifest) {
  const components = manifest.components.map((component) => {
    const entries = manifest.stateComponents[component.component];
    const root = hashJson("flowchain.production_l1.state_component_root.v0", { component: component.component, entries });
    if (root !== component.root) {
      throw new Error(`${ERROR_CODES.MALFORMED_STATE_ROOT}: component ${component.component}`);
    }
    return { component: component.component, root: component.root, count: component.count };
  });
  const stateRoot = hashJson("flowchain.production_l1.state_root.v0", {
    chainId: manifest.chainId,
    networkProfile: manifest.networkProfile,
    genesisHash: manifest.genesisHash,
    components
  });
  if (stateRoot !== manifest.stateRoot || manifest.deterministicReplay.sameLogicalStateRoot !== manifest.stateRoot) {
    throw new Error(`${ERROR_CODES.MALFORMED_STATE_ROOT}: state root`);
  }
}

function validateBlock(block, transactions, receipts, events, bridgeEvidence, stateRootManifest) {
  const headerBase = { ...block.header };
  delete headerBase.blockHash;
  const blockHash = hashJson("flowchain.production_l1.block_hash.v0", headerBase);
  if (blockHash !== block.header.blockHash) throw new Error(`block hash mismatch: ${block.header.blockHash}`);
  const roots = {
    txRoot: hashJson("flowchain.production_l1.tx_root.v0", transactions.map((tx) => tx.txId)),
    receiptRoot: hashJson("flowchain.production_l1.receipt_root.v0", receipts.map((receipt) => receipt.receiptId)),
    eventRoot: hashJson("flowchain.production_l1.event_root.v0", events.map((event) => event.eventId)),
    evidenceRoot: hashJson("flowchain.production_l1.evidence_root.v0", bridgeEvidence.map((evidence) => evidence.evidenceId))
  };
  for (const [field, root] of Object.entries(roots)) {
    if (block.header[field] !== root) throw new Error(`block ${field} mismatch`);
  }
  if (block.header.stateRoot !== stateRootManifest.stateRoot) {
    throw new Error(`${ERROR_CODES.MALFORMED_STATE_ROOT}: block state root`);
  }
}

function validateFinalityReceipt(finalityReceipt, block, profile) {
  if (finalityReceipt.blockHash !== block.header.blockHash) throw new Error("finality receipt block hash mismatch");
  if (finalityReceipt.stateRoot !== block.header.stateRoot) throw new Error("finality receipt state root mismatch");
  if (finalityReceipt.finalityRule !== profile.finalityRule.rule) throw new Error("finality rule mismatch");
}

function validateNegativeFixtures(negativeFixtures, genesis, profile) {
  const accountMap = Object.fromEntries(genesis.initialAccounts.map((account) => [account.accountId, account]));
  for (const entry of negativeFixtures.cases) {
    const actual = validateNegativeCase(entry, genesis, profile, accountMap);
    if (actual !== entry.expectedErrorCode) {
      throw new Error(`${entry.caseId} expected ${entry.expectedErrorCode} got ${actual}`);
    }
  }
}

function validateNegativeCase(entry, genesis, profile, accountMap) {
  try {
    if (entry.fixtureKind === "transaction") {
      return validateTransaction(entry.transaction, genesis, profile, accountMap, { expectedNonce: entry.expectedNonce }) ?? "UNEXPECTED_VALID";
    }
    if (entry.fixtureKind === "transaction_set") {
      const seen = new Set();
      for (const tx of entry.transactions) {
        if (seen.has(tx.txId)) return ERROR_CODES.DUPLICATE_TX;
        seen.add(tx.txId);
      }
      return "UNEXPECTED_VALID";
    }
    if (entry.fixtureKind === "state_root_manifest") {
      validateStateRootManifest(entry.stateRootManifest);
      return "UNEXPECTED_VALID";
    }
    if (entry.fixtureKind === "bridge_evidence") {
      if (!profile.allowedBridgeSourceChainIds.includes(entry.bridgeEvidence.sourceChainId)) {
        return ERROR_CODES.INVALID_BRIDGE_SOURCE_CHAIN;
      }
      return "UNEXPECTED_VALID";
    }
    if (entry.fixtureKind === "bridge_evidence_set") {
      const seen = new Set();
      for (const evidence of entry.bridgeEvidence) {
        const key = canonicalJson(sourceEventKey(evidence));
        if (seen.has(key)) return ERROR_CODES.DUPLICATE_BRIDGE_EVENT;
        seen.add(key);
      }
      return "UNEXPECTED_VALID";
    }
    return ERROR_CODES.SCHEMA;
  } catch (error) {
    const message = String(error.message ?? error);
    const code = Object.values(ERROR_CODES).find((entryCode) => message.includes(entryCode));
    return code ?? ERROR_CODES.SCHEMA;
  }
}

function assertEqualSets(actual, expected, label) {
  const actualSorted = [...actual].sort();
  const expectedSorted = [...expected].sort();
  if (canonicalJson(actualSorted) !== canonicalJson(expectedSorted)) {
    throw new Error(`${label} mismatch: expected ${expectedSorted.join(", ")} got ${actualSorted.join(", ")}`);
  }
}

function assertKeccak() {
  const empty = keccakHex("");
  const abc = keccakHex("abc");
  if (empty !== "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470") {
    throw new Error(`keccak self-test failed for empty string: ${empty}`);
  }
  if (abc !== "0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45") {
    throw new Error(`keccak self-test failed for abc: ${abc}`);
  }
}

function printGenesisHash() {
  const genesisPath = resolve(fixturesDir, "genesis.json");
  const genesis = existsSync(genesisPath) ? readJson(genesisPath) : buildAll().genesis;
  console.log(genesis.genesisHash);
}

async function main() {
  const command = process.argv[2] ?? "help";
  if (command === "write") {
    const all = writeSchemasAndFixtures();
    console.log(`FLOWCHAIN_PRODUCTION_L1_WRITE_OK schemas=${Object.keys(buildSchemas()).length} transactions=${all.transactions.length} negativeCases=${all.negativeFixtures.cases.length}`);
    return;
  }
  if (command === "build-genesis") {
    const all = buildAll();
    writeJson(resolve(fixturesDir, "genesis.json"), all.genesis);
    console.log(`FLOWCHAIN_PRODUCTION_L1_GENESIS_BUILD_OK genesisHash=${all.genesis.genesisHash}`);
    return;
  }
  if (command === "validate-genesis") {
    const input = readJson(resolve(fixturesDir, "genesis.input.json"));
    const genesis = readJson(resolve(fixturesDir, "genesis.json"));
    validateGenesisHash(input, genesis);
    console.log(`FLOWCHAIN_PRODUCTION_L1_GENESIS_OK genesisHash=${genesis.genesisHash}`);
    return;
  }
  if (command === "genesis-hash") {
    printGenesisHash();
    return;
  }
  if (command === "validate-protocol") {
    const result = await validateProtocol();
    console.log(`FLOWCHAIN_PRODUCTION_L1_PROTOCOL_OK schemas=${result.schemas} profiles=${result.profiles} payloadTypes=${result.payloadTypes}`);
    return;
  }
  if (command === "validate-fixtures") {
    const result = await validateFixtures();
    console.log(`FLOWCHAIN_PRODUCTION_L1_FIXTURES_OK transactions=${result.transactions} receipts=${result.receipts} events=${result.events} bridgeEvidence=${result.bridgeEvidence} negativeCases=${result.negativeCases} genesisHash=${result.genesisHash} stateRoot=${result.stateRoot}`);
    return;
  }
  console.log("usage: node fixtures/production-l1/production-l1-tools.mjs <write|build-genesis|validate-genesis|genesis-hash|validate-protocol|validate-fixtures>");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
