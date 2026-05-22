import {
  bytesToHex,
  encodeAddress,
  encodeBytes32,
  encodeUint256,
  hexToBytes,
  keccak256Utf8,
  normalizeAddress,
  normalizeBytes32,
  normalizeHex,
  type Hex,
} from "../../shared/src/index.ts";
import {
  buildPublicAgentLaunchContractHashes,
  type PublicAgentLaunchContractHashes,
  type PublicAgentLaunchIntent,
} from "../../flowmemory/src/public-agent-network.ts";
import {
  buildPublicSwarmLaunchContractHashes,
  type PublicSwarmLaunchContractHashes,
  type PublicSwarmLaunchIntent,
} from "../../flowmemory/src/public-swarm-network.ts";

const ZERO_ADDRESS = normalizeAddress("0x0000000000000000000000000000000000000000");
const ZERO_BYTES32 = normalizeBytes32("0x0000000000000000000000000000000000000000000000000000000000000000");

const LAUNCH_AGENT_SIGNATURE = "launchAgent((address,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint8,bytes32,bytes32,address,uint256,address,uint256,bool,uint64,uint64,uint64,bytes32),bytes,(bool,address))";
const CREATE_SWARM_SIGNATURE = "createSwarm(bytes32,(address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,address,uint256,uint64,uint64,uint64,bytes32,bytes32),(uint8,address,bytes32,bytes32,address,bytes32,bytes32,uint16,bool,uint64,uint64)[])";

export interface PreparedContractTransaction {
  to: string;
  data: Hex;
  value: Hex;
  method: string;
  selector: Hex;
}

export interface PublicAgentLaunchPaymentInput {
  sponsorMode: boolean;
  sponsor?: string;
}

export interface PreparedPublicAgentLaunchTransaction {
  tx: PreparedContractTransaction;
  hashes: PublicAgentLaunchContractHashes;
  signatureBytesLength: number;
}

export type PublicSwarmMemberType = "wallet" | "agent" | "swarm" | "shell";

export interface PublicSwarmMemberInput {
  memberType: PublicSwarmMemberType;
  wallet?: string;
  agentId?: string;
  childSwarmId?: string;
  shell?: string;
  role: string;
  permissionsRoot: string;
  weight: string | number | bigint;
  active: boolean;
  joinedAt?: string | number | bigint;
  updatedAt?: string | number | bigint;
}

export interface PreparedPublicSwarmCreateTransaction {
  tx: PreparedContractTransaction;
  hashes: PublicSwarmLaunchContractHashes;
  memberCount: number;
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const length = parts.reduce((sum, part) => sum + part.length, 0);
  const output = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function encodeBool(value: boolean): Uint8Array {
  return encodeUint256(value ? 1 : 0);
}

function encodeDynamicBytes(value: string): Uint8Array {
  const normalized = normalizeHex(value);
  const bytes = hexToBytes(normalized);
  const padded = new Uint8Array(Math.ceil(bytes.length / 32) * 32);
  padded.set(bytes);
  return concatBytes([encodeUint256(bytes.length), padded]);
}

function functionSelector(signature: string): Hex {
  return keccak256Utf8(signature).slice(0, 10) as Hex;
}

function hexQuantity(value: string | number | bigint): Hex {
  const bigintValue = BigInt(value);
  if (bigintValue < 0n) {
    throw new Error("transaction value cannot be negative");
  }
  return `0x${bigintValue.toString(16)}` as Hex;
}

function wordOffset(words: number): Uint8Array {
  return encodeUint256(words * 32);
}

function memberTypeCode(value: PublicSwarmMemberType): bigint {
  switch (value) {
    case "wallet":
      return 0n;
    case "agent":
      return 1n;
    case "swarm":
      return 2n;
    case "shell":
      return 3n;
    default:
      throw new Error(`unsupported swarm member type: ${String(value)}`);
  }
}

function encodeAgentIntentWords(intent: PublicAgentLaunchIntent): Uint8Array[] {
  return [
    encodeAddress(intent.owner),
    encodeAddress(intent.operator),
    encodeBytes32(intent.classId),
    encodeBytes32(intent.rootfieldId),
    encodeBytes32(intent.kernelClass),
    encodeBytes32(intent.policyRoot),
    encodeBytes32(intent.toolAllowlistRoot),
    encodeBytes32(intent.initialMemoryRoot),
    encodeBytes32(intent.activeGoalRoot),
    encodeBytes32(intent.profileDigest),
    encodeBytes32(intent.launchSpecRoot),
    encodeUint256(intent.autonomyLevel),
    encodeUint256(intent.riskLevel),
    encodeBytes32(intent.parentAgentId),
    encodeBytes32(intent.parentSwarmId),
    encodeAddress(intent.bondToken),
    encodeUint256(intent.bondAmount),
    encodeAddress(intent.fuelToken),
    encodeUint256(intent.initialFuelAmount),
    encodeBool(intent.discoverable),
    encodeUint256(intent.validAfter),
    encodeUint256(intent.validUntil),
    encodeUint256(intent.nonce),
    encodeBytes32(intent.salt),
  ];
}

function encodeSwarmIntentWords(intent: PublicSwarmLaunchIntent): Uint8Array[] {
  return [
    encodeAddress(intent.creator),
    encodeBytes32(intent.swarmClass),
    encodeBytes32(intent.missionRoot),
    encodeBytes32(intent.sharedMemoryRoot),
    encodeBytes32(intent.policyRoot),
    encodeBytes32(intent.roleRoot),
    encodeBytes32(intent.profileDigest),
    encodeAddress(intent.budgetAsset),
    encodeUint256(intent.initialBudget),
    encodeUint256(intent.validAfter),
    encodeUint256(intent.validUntil),
    encodeUint256(intent.nonce),
    encodeBytes32(intent.parentSwarmId),
    encodeBytes32(intent.salt),
  ];
}

function encodeSwarmMemberWords(member: PublicSwarmMemberInput): Uint8Array[] {
  return [
    encodeUint256(memberTypeCode(member.memberType)),
    encodeAddress(member.wallet ?? ZERO_ADDRESS),
    encodeBytes32(member.agentId ?? ZERO_BYTES32),
    encodeBytes32(member.childSwarmId ?? ZERO_BYTES32),
    encodeAddress(member.shell ?? ZERO_ADDRESS),
    encodeBytes32(member.role),
    encodeBytes32(member.permissionsRoot),
    encodeUint256(member.weight),
    encodeBool(member.active),
    encodeUint256(member.joinedAt ?? 0),
    encodeUint256(member.updatedAt ?? 0),
  ];
}

export function buildPublicAgentLaunchTransaction(input: {
  factory: string;
  chainId: string | number | bigint;
  intent: PublicAgentLaunchIntent;
  ownerSignature: string;
  payment?: PublicAgentLaunchPaymentInput;
  eip712Name?: string;
  eip712Version?: string;
  value?: string | number | bigint;
}): PreparedPublicAgentLaunchTransaction {
  const factory = normalizeAddress(input.factory);
  const signatureBytes = hexToBytes(normalizeHex(input.ownerSignature));
  if (signatureBytes.length !== 65) {
    throw new Error(`ownerSignature must be 65 bytes, got ${signatureBytes.length}`);
  }

  const payment = {
    sponsorMode: input.payment?.sponsorMode ?? false,
    sponsor: normalizeAddress(input.payment?.sponsor ?? ZERO_ADDRESS),
  };
  if (payment.sponsorMode && payment.sponsor === ZERO_ADDRESS) {
    throw new Error("sponsor address is required when sponsorMode is true");
  }

  const intentWords = encodeAgentIntentWords(input.intent);
  const paymentWords = [encodeBool(payment.sponsorMode), encodeAddress(payment.sponsor)];
  const dynamicOffsetWords = intentWords.length + 1 + paymentWords.length;
  const body = concatBytes([
    ...intentWords,
    wordOffset(dynamicOffsetWords),
    ...paymentWords,
    encodeDynamicBytes(input.ownerSignature),
  ]);

  return {
    tx: {
      to: factory,
      data: bytesToHex(concatBytes([hexToBytes(functionSelector(LAUNCH_AGENT_SIGNATURE)), body])),
      value: hexQuantity(input.value ?? 0),
      method: "launchAgent",
      selector: functionSelector(LAUNCH_AGENT_SIGNATURE),
    },
    hashes: buildPublicAgentLaunchContractHashes(input.intent, {
      chainId: input.chainId,
      verifyingContract: factory,
      eip712Name: input.eip712Name,
      eip712Version: input.eip712Version,
    }),
    signatureBytesLength: signatureBytes.length,
  };
}

export function buildPublicSwarmCreateTransaction(input: {
  factory: string;
  chainId: string | number | bigint;
  policyId: string;
  intent: PublicSwarmLaunchIntent;
  initialMembers?: PublicSwarmMemberInput[];
  value?: string | number | bigint;
}): PreparedPublicSwarmCreateTransaction {
  const factory = normalizeAddress(input.factory);
  const members = input.initialMembers ?? [];
  const policyId = normalizeBytes32(input.policyId);
  const intentWords = encodeSwarmIntentWords(input.intent);
  const membersHeadWords = 1 + intentWords.length + 1;
  const membersTail = concatBytes([
    encodeUint256(members.length),
    ...members.flatMap((member) => encodeSwarmMemberWords(member)),
  ]);
  const body = concatBytes([
    encodeBytes32(policyId),
    ...intentWords,
    wordOffset(membersHeadWords),
    membersTail,
  ]);

  return {
    tx: {
      to: factory,
      data: bytesToHex(concatBytes([hexToBytes(functionSelector(CREATE_SWARM_SIGNATURE)), body])),
      value: hexQuantity(input.value ?? 0),
      method: "createSwarm",
      selector: functionSelector(CREATE_SWARM_SIGNATURE),
    },
    hashes: buildPublicSwarmLaunchContractHashes(input.intent, {
      chainId: input.chainId,
      factory,
    }),
    memberCount: members.length,
  };
}
