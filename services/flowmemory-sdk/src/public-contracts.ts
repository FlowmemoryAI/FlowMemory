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

const PUBLIC_AGENT_CONTRACT_EVENT_SIGNATURES = {
  LaunchIntentConsumed: "LaunchIntentConsumed(bytes32,address,bytes32,uint64)",
  AgentLaunched: "AgentLaunched(bytes32,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint8)",
  LaunchBondLocked: "LaunchBondLocked(bytes32,address,address,address,uint256,bytes32,uint64)",
  FuelAccountRegistered: "FuelAccountRegistered(bytes32,address,bytes32,address)",
  MemoryFuelDeposited: "MemoryFuelDeposited(bytes32,address,address,uint256)",
  SwarmCreated: "SwarmCreated(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)",
  SwarmLaunched: "SwarmLaunched(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)",
  SwarmBudgetDeposited: "SwarmBudgetDeposited(bytes32,address,address,uint256)",
  SwarmBudgetLineCreated: "SwarmBudgetLineCreated(bytes32,bytes32,address,uint256,bytes32,bytes32)",
  SwarmBudgetReserved: "SwarmBudgetReserved(bytes32,bytes32,bytes32,uint256,bytes32)",
  SwarmBudgetReleased: "SwarmBudgetReleased(bytes32,bytes32,bytes32,uint256)",
  SwarmBudgetSpent: "SwarmBudgetSpent(bytes32,bytes32,bytes32,address,address,uint256,bytes32)",
} as const;

export const PUBLIC_AGENT_CONTRACT_EVENT_TOPICS = Object.fromEntries(
  Object.entries(PUBLIC_AGENT_CONTRACT_EVENT_SIGNATURES).map(([name, signature]) => [name, keccak256Utf8(signature)]),
) as Record<keyof typeof PUBLIC_AGENT_CONTRACT_EVENT_SIGNATURES, Hex>;

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

export interface Eip1193Provider {
  request<T = unknown>(args: { method: string; params?: unknown[] }): Promise<T>;
}

export interface PublicAgentLaunchTypedData {
  domain: {
    name: string;
    version: string;
    chainId: string;
    verifyingContract: string;
  };
  types: {
    EIP712Domain: Array<{ name: string; type: string }>;
    LaunchIntent: Array<{ name: string; type: string }>;
  };
  primaryType: "LaunchIntent";
  message: {
    owner: string;
    operator: string;
    classId: string;
    rootfieldId: string;
    kernelClass: string;
    rootsHash: string;
    configHash: string;
    lineageHash: string;
    fundingHash: string;
    nonce: string;
    salt: string;
  };
}

export interface PublicAgentLaunchTypedDataRequest {
  typedData: PublicAgentLaunchTypedData;
  hashes: PublicAgentLaunchContractHashes;
}

export interface SubmittedContractTransaction {
  transactionHash: Hex;
  request: {
    from: string;
    to: string;
    data: Hex;
    value: Hex;
  };
}

export interface WaitForTransactionReceiptOptions {
  maxAttempts?: number;
  pollIntervalMs?: number;
}

export interface EvmTransactionReceiptLog {
  address: string;
  topics: string[];
  data: string;
  blockNumber?: string;
  transactionHash?: string;
  transactionIndex?: string;
  logIndex?: string;
  removed?: boolean;
}

export interface EvmTransactionReceipt {
  transactionHash: string;
  status: string;
  blockNumber?: string;
  logs: EvmTransactionReceiptLog[];
}

export interface DecodedPublicContractEvent {
  name: keyof typeof PUBLIC_AGENT_CONTRACT_EVENT_SIGNATURES;
  group: "launch" | "bond" | "fuel" | "swarm";
  address: string;
  topics: string[];
  data: string;
  launchIntentHash?: string;
  launchId?: string;
  agentId?: string;
  owner?: string;
  classId?: string;
  payer?: string;
  beneficiary?: string;
  swarmId?: string;
  creator?: string;
  budgetLineId?: string;
  reservationId?: string;
  spendId?: string;
  transactionHash?: string;
  logIndex?: string;
}

export interface DecodedPublicContractReceipt {
  transactionHash: Hex;
  status: "success" | "reverted";
  successful: boolean;
  events: DecodedPublicContractEvent[];
  agentLaunches: Array<{ launchIntentHash: string; launchId: string; agentId: string; address: string }>;
  swarmLaunches: Array<{ swarmId: string; creator: string; address: string }>;
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

function normalizeTransactionHash(value: unknown): Hex {
  if (typeof value !== "string") {
    throw new Error("transaction hash must be a string");
  }
  const normalized = normalizeHex(value);
  if (hexToBytes(normalized).length !== 32) {
    throw new Error("transaction hash must be 32 bytes");
  }
  return normalized;
}

function normalizeSignature(value: unknown): Hex {
  if (typeof value !== "string") {
    throw new Error("signature must be a string");
  }
  const normalized = normalizeHex(value);
  if (hexToBytes(normalized).length !== 65) {
    throw new Error("signature must be 65 bytes");
  }
  return normalized;
}

function topicAddress(topic: string): string {
  const normalized = normalizeBytes32(topic);
  return normalizeAddress(`0x${normalized.slice(-40)}`);
}

function topicBytes32(topics: string[], index: number): string | undefined {
  const topic = topics[index];
  return topic === undefined ? undefined : normalizeBytes32(topic);
}

function eventTopicName(topic0: string): keyof typeof PUBLIC_AGENT_CONTRACT_EVENT_SIGNATURES | null {
  const normalized = normalizeBytes32(topic0).toLowerCase();
  for (const [name, topic] of Object.entries(PUBLIC_AGENT_CONTRACT_EVENT_TOPICS)) {
    if (topic.toLowerCase() === normalized) return name as keyof typeof PUBLIC_AGENT_CONTRACT_EVENT_SIGNATURES;
  }
  return null;
}

function sleep(ms: number): Promise<void> {
  return ms <= 0 ? Promise.resolve() : new Promise((resolve) => setTimeout(resolve, ms));
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

export function buildPublicAgentLaunchTypedData(input: {
  factory: string;
  chainId: string | number | bigint;
  intent: PublicAgentLaunchIntent;
  eip712Name?: string;
  eip712Version?: string;
}): PublicAgentLaunchTypedDataRequest {
  const factory = normalizeAddress(input.factory);
  const hashes = buildPublicAgentLaunchContractHashes(input.intent, {
    chainId: input.chainId,
    verifyingContract: factory,
    eip712Name: input.eip712Name,
    eip712Version: input.eip712Version,
  });

  return {
    hashes,
    typedData: {
      domain: {
        name: input.eip712Name ?? "FlowMemory AgentFactory",
        version: input.eip712Version ?? "1",
        chainId: BigInt(input.chainId).toString(),
        verifyingContract: factory,
      },
      types: {
        EIP712Domain: [
          { name: "name", type: "string" },
          { name: "version", type: "string" },
          { name: "chainId", type: "uint256" },
          { name: "verifyingContract", type: "address" },
        ],
        LaunchIntent: [
          { name: "owner", type: "address" },
          { name: "operator", type: "address" },
          { name: "classId", type: "bytes32" },
          { name: "rootfieldId", type: "bytes32" },
          { name: "kernelClass", type: "bytes32" },
          { name: "rootsHash", type: "bytes32" },
          { name: "configHash", type: "bytes32" },
          { name: "lineageHash", type: "bytes32" },
          { name: "fundingHash", type: "bytes32" },
          { name: "nonce", type: "uint64" },
          { name: "salt", type: "bytes32" },
        ],
      },
      primaryType: "LaunchIntent",
      message: {
        owner: normalizeAddress(input.intent.owner),
        operator: normalizeAddress(input.intent.operator),
        classId: normalizeBytes32(input.intent.classId),
        rootfieldId: normalizeBytes32(input.intent.rootfieldId),
        kernelClass: normalizeBytes32(input.intent.kernelClass),
        rootsHash: hashes.rootsHash,
        configHash: hashes.configHash,
        lineageHash: hashes.lineageHash,
        fundingHash: hashes.fundingHash,
        nonce: BigInt(input.intent.nonce).toString(),
        salt: normalizeBytes32(input.intent.salt),
      },
    },
  };
}

export async function signPublicAgentLaunchIntent(input: {
  provider: Eip1193Provider;
  factory: string;
  chainId: string | number | bigint;
  intent: PublicAgentLaunchIntent;
  owner?: string;
  eip712Name?: string;
  eip712Version?: string;
}): Promise<Hex> {
  const owner = normalizeAddress(input.owner ?? input.intent.owner);
  const { typedData } = buildPublicAgentLaunchTypedData(input);
  const signature = await input.provider.request({
    method: "eth_signTypedData_v4",
    params: [owner, JSON.stringify(typedData)],
  });
  return normalizeSignature(signature);
}

export async function submitPreparedContractTransaction(input: {
  provider: Eip1193Provider;
  from: string;
  tx: PreparedContractTransaction;
}): Promise<SubmittedContractTransaction> {
  const request = {
    from: normalizeAddress(input.from),
    to: normalizeAddress(input.tx.to),
    data: normalizeHex(input.tx.data),
    value: hexQuantity(input.tx.value),
  };
  const transactionHash = await input.provider.request({
    method: "eth_sendTransaction",
    params: [request],
  });
  return {
    transactionHash: normalizeTransactionHash(transactionHash),
    request,
  };
}

export async function submitPublicAgentLaunchTransaction(input: {
  provider: Eip1193Provider;
  from: string;
  prepared: PreparedPublicAgentLaunchTransaction;
}): Promise<SubmittedContractTransaction> {
  return submitPreparedContractTransaction({
    provider: input.provider,
    from: input.from,
    tx: input.prepared.tx,
  });
}

export async function submitPublicSwarmCreateTransaction(input: {
  provider: Eip1193Provider;
  from: string;
  prepared: PreparedPublicSwarmCreateTransaction;
}): Promise<SubmittedContractTransaction> {
  return submitPreparedContractTransaction({
    provider: input.provider,
    from: input.from,
    tx: input.prepared.tx,
  });
}

export async function waitForTransactionReceipt(input: {
  provider: Eip1193Provider;
  transactionHash: string;
  options?: WaitForTransactionReceiptOptions;
}): Promise<EvmTransactionReceipt> {
  const transactionHash = normalizeTransactionHash(input.transactionHash);
  const maxAttempts = input.options?.maxAttempts ?? 30;
  const pollIntervalMs = input.options?.pollIntervalMs ?? 1_000;
  if (maxAttempts <= 0) {
    throw new Error("maxAttempts must be greater than zero");
  }

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const receipt = await input.provider.request({
      method: "eth_getTransactionReceipt",
      params: [transactionHash],
    });
    if (receipt !== null) {
      if (typeof receipt !== "object" || Array.isArray(receipt)) {
        throw new Error("transaction receipt must be an object or null");
      }
      const candidate = receipt as Partial<EvmTransactionReceipt>;
      if (typeof candidate.transactionHash !== "string" || typeof candidate.status !== "string" || !Array.isArray(candidate.logs)) {
        throw new Error("transaction receipt is missing transactionHash, status, or logs");
      }
      return {
        transactionHash: normalizeTransactionHash(candidate.transactionHash),
        status: candidate.status,
        blockNumber: candidate.blockNumber,
        logs: candidate.logs,
      };
    }
    if (attempt + 1 < maxAttempts) await sleep(pollIntervalMs);
  }

  throw new Error(`transaction receipt not available after ${maxAttempts} attempts`);
}

export function decodePublicContractReceipt(receipt: EvmTransactionReceipt): DecodedPublicContractReceipt {
  const transactionHash = normalizeTransactionHash(receipt.transactionHash);
  const status = receipt.status === "0x1" ? "success" : receipt.status === "0x0" ? "reverted" : null;
  if (status === null) {
    throw new Error(`unsupported receipt status: ${receipt.status}`);
  }

  const events: DecodedPublicContractEvent[] = [];
  for (const log of receipt.logs) {
    if (!Array.isArray(log.topics) || log.topics.length === 0) continue;
    const name = eventTopicName(log.topics[0]);
    if (name === null) continue;
    const address = normalizeAddress(log.address);
    const topics = log.topics.map((topic) => normalizeBytes32(topic));
    const base = {
      name,
      address,
      topics,
      data: normalizeHex(log.data),
      transactionHash: log.transactionHash === undefined ? transactionHash : normalizeTransactionHash(log.transactionHash),
      logIndex: log.logIndex,
    };

    if (name === "AgentLaunched") {
      const launchIntentHash = topicBytes32(topics, 1);
      const launchId = topicBytes32(topics, 2);
      const agentId = topicBytes32(topics, 3);
      if (launchIntentHash && launchId && agentId) {
        events.push({ ...base, group: "launch", launchIntentHash, launchId, agentId });
      }
    } else if (name === "LaunchIntentConsumed") {
      const launchIntentHash = topicBytes32(topics, 1);
      const ownerTopic = topics[2];
      const classId = topicBytes32(topics, 3);
      if (launchIntentHash && ownerTopic && classId) {
        events.push({ ...base, group: "launch", launchIntentHash, owner: topicAddress(ownerTopic), classId });
      }
    } else if (name === "LaunchBondLocked") {
      const agentId = topicBytes32(topics, 1);
      const payerTopic = topics[2];
      const beneficiaryTopic = topics[3];
      if (agentId && payerTopic && beneficiaryTopic) {
        events.push({ ...base, group: "bond", agentId, payer: topicAddress(payerTopic), beneficiary: topicAddress(beneficiaryTopic) });
      }
    } else if (name === "FuelAccountRegistered" || name === "MemoryFuelDeposited") {
      const agentId = topicBytes32(topics, 1);
      const ownerTopic = topics[2];
      const classId = name === "FuelAccountRegistered" ? topicBytes32(topics, 3) : undefined;
      if (agentId && ownerTopic) {
        events.push({ ...base, group: "fuel", agentId, owner: topicAddress(ownerTopic), classId });
      }
    } else if (name === "SwarmCreated" || name === "SwarmLaunched") {
      const swarmId = topicBytes32(topics, 1);
      const creatorTopic = topics[2];
      if (swarmId && creatorTopic) {
        events.push({ ...base, group: "swarm", swarmId, creator: topicAddress(creatorTopic) });
      }
    } else if (name === "SwarmBudgetDeposited") {
      const swarmId = topicBytes32(topics, 1);
      const payerTopic = topics[2];
      if (swarmId && payerTopic) {
        events.push({ ...base, group: "swarm", swarmId, payer: topicAddress(payerTopic) });
      }
    } else if (name === "SwarmBudgetLineCreated") {
      const swarmId = topicBytes32(topics, 1);
      const budgetLineId = topicBytes32(topics, 2);
      if (swarmId && budgetLineId) {
        events.push({ ...base, group: "swarm", swarmId, budgetLineId });
      }
    } else if (name === "SwarmBudgetReserved" || name === "SwarmBudgetReleased") {
      const swarmId = topicBytes32(topics, 1);
      const budgetLineId = topicBytes32(topics, 2);
      const reservationId = topicBytes32(topics, 3);
      if (swarmId && budgetLineId && reservationId) {
        events.push({ ...base, group: "swarm", swarmId, budgetLineId, reservationId });
      }
    } else if (name === "SwarmBudgetSpent") {
      const swarmId = topicBytes32(topics, 1);
      const budgetLineId = topicBytes32(topics, 2);
      const spendId = topicBytes32(topics, 3);
      if (swarmId && budgetLineId && spendId) {
        events.push({ ...base, group: "swarm", swarmId, budgetLineId, spendId });
      }
    }
  }

  return {
    transactionHash,
    status,
    successful: status === "success",
    events,
    agentLaunches: events
      .filter((event): event is DecodedPublicContractEvent & { launchIntentHash: string; launchId: string; agentId: string } => event.name === "AgentLaunched" && event.launchIntentHash !== undefined && event.launchId !== undefined && event.agentId !== undefined)
      .map((event) => ({ launchIntentHash: event.launchIntentHash, launchId: event.launchId, agentId: event.agentId, address: event.address })),
    swarmLaunches: events
      .filter((event): event is DecodedPublicContractEvent & { swarmId: string; creator: string } => event.name === "SwarmLaunched" && event.swarmId !== undefined && event.creator !== undefined)
      .map((event) => ({ swarmId: event.swarmId, creator: event.creator, address: event.address })),
  };
}
