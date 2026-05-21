import { canonicalJson, encodeAddress, encodeBytes32, encodeUint256, hexToBytes, keccak256Hex, keccak256Utf8 } from "../../shared/src/index.ts";

export interface PublicAgentClassConfig {
  classId: string;
  className: string;
  version: number;
  kernelClass: string;
  maxAutonomyLevel: number;
  minAutonomyLevel: number;
  maxToolRiskTier: number;
  maxTools: number;
  minLaunchBond: string;
  minMemoryFuel: string;
  allowPublicLaunch: boolean;
  allowSwarmMembership: boolean;
  allowShellGraduation: boolean;
  metadataDigest: string;
}

export interface PublicToolConfig {
  toolId: string;
  toolName: string;
  toolSetRoot: string;
  riskTier: number;
  mutating: boolean;
  requiresDryRun: boolean;
  requiresHumanConfirm: boolean;
  metadataDigest: string;
}

export interface PublicAgentLaunchInput {
  owner: string;
  classId: string;
  objectiveText: string;
  profileText: string;
  toolSetRoot: string;
  autonomyLevel: number;
  riskLevel: number;
  bondToken: string;
  bondAmount: string;
  fuelToken: string;
  initialFuelAmount: string;
  discoverable: boolean;
  parentAgentId?: string;
  parentSwarmId?: string;
}

export interface PublicAgentLaunchIntent {
  owner: string;
  operator: string;
  classId: string;
  rootfieldId: string;
  kernelClass: string;
  policyRoot: string;
  toolAllowlistRoot: string;
  initialMemoryRoot: string;
  activeGoalRoot: string;
  profileDigest: string;
  launchSpecRoot: string;
  autonomyLevel: number;
  riskLevel: number;
  parentAgentId: string;
  parentSwarmId: string;
  bondToken: string;
  bondAmount: string;
  fuelToken: string;
  initialFuelAmount: string;
  discoverable: boolean;
  validAfter: string;
  validUntil: string;
  nonce: string;
  salt: string;
}


export interface PublicAgentLaunchRecord {
  launchId: string;
  agentId: string;
  owner: string;
  classId: string;
  className: string;
  profileDigest: string;
  policyRoot: string;
  toolAllowlistRoot: string;
  initialMemoryRoot: string;
  activeGoalRoot: string;
  bondToken: string;
  bondAmount: string;
  fuelToken: string;
  initialFuelAmount: string;
  discoverable: boolean;
}
export interface PublicAgentLaunchPreview {
  classConfig: PublicAgentClassConfig;
  toolConfig: PublicToolConfig | null;
  policyRoot: string;
  toolAllowlistRoot: string;
  initialMemoryRoot: string;
  activeGoalRoot: string;
  profileDigest: string;
  launchSpecRoot: string;
  warnings: string[];
  valid: boolean;
}

export interface PublicAgentLaunchContractHashes {
  domainSeparator: string;
  rootsHash: string;
  configHash: string;
  lineageHash: string;
  fundingHash: string;
  structHash: string;
  digest: string;
  launchId: string;
}

const DEFAULT_CLASSES: PublicAgentClassConfig[] = [
  {
    classId: keccak256Utf8("TASK_SCOUT_V0"),
    className: "Task Scout",
    version: 1,
    kernelClass: keccak256Utf8("flowmemory.kernel.task_scout.rule_scoring.v1"),
    minAutonomyLevel: 1,
    maxAutonomyLevel: 3,
    maxToolRiskTier: 2,
    maxTools: 4,
    minLaunchBond: "10000000000000000000",
    minMemoryFuel: "5000000000000000000",
    allowPublicLaunch: true,
    allowSwarmMembership: true,
    allowShellGraduation: false,
    metadataDigest: keccak256Utf8("class.task-scout.v0"),
  },
  {
    classId: keccak256Utf8("RESEARCH_SYNTH_AGENT_V0"),
    className: "Research Synth Agent",
    version: 1,
    kernelClass: keccak256Utf8("flowmemory.kernel.research_synth.v0"),
    minAutonomyLevel: 1,
    maxAutonomyLevel: 2,
    maxToolRiskTier: 1,
    maxTools: 3,
    minLaunchBond: "15000000000000000000",
    minMemoryFuel: "7000000000000000000",
    allowPublicLaunch: true,
    allowSwarmMembership: true,
    allowShellGraduation: false,
    metadataDigest: keccak256Utf8("class.research-synth.v0"),
  },
  {
    classId: keccak256Utf8("SWARM_COORDINATOR_V0"),
    className: "Swarm Coordinator",
    version: 1,
    kernelClass: keccak256Utf8("flowmemory.kernel.swarm_coordinator.v0"),
    minAutonomyLevel: 2,
    maxAutonomyLevel: 4,
    maxToolRiskTier: 3,
    maxTools: 6,
    minLaunchBond: "25000000000000000000",
    minMemoryFuel: "10000000000000000000",
    allowPublicLaunch: true,
    allowSwarmMembership: true,
    allowShellGraduation: true,
    metadataDigest: keccak256Utf8("class.swarm-coordinator.v0"),
  },
];

const DEFAULT_TOOLS: PublicToolConfig[] = [
  {
    toolId: keccak256Utf8("tool.accept.task.v0"),
    toolName: "Task Accept",
    toolSetRoot: keccak256Utf8("toolset.task-scout.v0"),
    riskTier: 2,
    mutating: true,
    requiresDryRun: true,
    requiresHumanConfirm: false,
    metadataDigest: keccak256Utf8("tool.accept.task.v0.meta"),
  },
  {
    toolId: keccak256Utf8("tool.memory.update.v0"),
    toolName: "Memory Only Update",
    toolSetRoot: keccak256Utf8("toolset.memory-curator.v0"),
    riskTier: 1,
    mutating: true,
    requiresDryRun: false,
    requiresHumanConfirm: false,
    metadataDigest: keccak256Utf8("tool.memory.update.v0.meta"),
  },
  {
    toolId: keccak256Utf8("tool.swarm.join.v0"),
    toolName: "Swarm Join",
    toolSetRoot: keccak256Utf8("toolset.swarm-coordinator.v0"),
    riskTier: 3,
    mutating: true,
    requiresDryRun: true,
    requiresHumanConfirm: true,
    metadataDigest: keccak256Utf8("tool.swarm.join.v0.meta"),
  },
];

function stableRoot(schema: string, value: unknown): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value } as Record<string, unknown>)));
}

const EIP712_DOMAIN_TYPEHASH = keccak256Utf8("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
const LAUNCH_INTENT_TYPEHASH = keccak256Utf8("LaunchIntent(address owner,address operator,bytes32 classId,bytes32 rootfieldId,bytes32 kernelClass,bytes32 rootsHash,bytes32 configHash,bytes32 lineageHash,bytes32 fundingHash,uint64 nonce,bytes32 salt)");
const EIP712_PREFIX = new Uint8Array([0x19, 0x01]);

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

function abiEncodeWords(parts: Uint8Array[]): Uint8Array {
  return concatBytes(parts);
}

function encodeBool(value: boolean): Uint8Array {
  return encodeUint256(value ? 1 : 0);
}

function hashWords(parts: Uint8Array[]): string {
  return keccak256Hex(abiEncodeWords(parts));
}

export function listPublicAgentClasses(): PublicAgentClassConfig[] {
  return [...DEFAULT_CLASSES];
}

export function getPublicAgentClass(classId: string): PublicAgentClassConfig | null {
  return DEFAULT_CLASSES.find((entry) => entry.classId === classId) ?? null;
}

export function listPublicTools(): PublicToolConfig[] {
  return [...DEFAULT_TOOLS];
}

export function getPublicToolSet(toolSetRoot: string): PublicToolConfig[] {
  return DEFAULT_TOOLS.filter((entry) => entry.toolSetRoot === toolSetRoot);
}

export function buildPublicAgentLaunchPreview(input: PublicAgentLaunchInput): PublicAgentLaunchPreview {
  const classConfig = getPublicAgentClass(input.classId);
  if (classConfig === null) {
    throw new Error(`unknown public agent class: ${input.classId}`);
  }
  const tools = getPublicToolSet(input.toolSetRoot);
  const highestRisk = tools.reduce((max, tool) => Math.max(max, tool.riskTier), 0);
  const toolConfig = tools[0] ?? null;

  const activeGoalRoot = stableRoot("flowmemory.public_agent.goal.v1", input.objectiveText);
  const profileDigest = stableRoot("flowmemory.public_agent.profile.v1", input.profileText);
  const policyRoot = stableRoot("flowmemory.public_agent.policy.v1", {
    classId: input.classId,
    autonomyLevel: input.autonomyLevel,
    riskLevel: input.riskLevel,
    objectiveText: input.objectiveText,
  });
  const initialMemoryRoot = stableRoot("flowmemory.public_agent.memory_root.v1", {
    classId: input.classId,
    objectiveText: input.objectiveText,
    parentAgentId: input.parentAgentId ?? null,
    parentSwarmId: input.parentSwarmId ?? null,
  });
  const launchSpecRoot = stableRoot("flowmemory.public_agent.launch_spec.v1", input);

  const warnings: string[] = [];
  if (!classConfig.allowPublicLaunch) warnings.push("class.not_launchable");
  if (input.autonomyLevel < classConfig.minAutonomyLevel || input.autonomyLevel > classConfig.maxAutonomyLevel) {
    warnings.push("class.autonomy_out_of_range");
  }
  if (tools.length > classConfig.maxTools) warnings.push("toolset.too_large");
  if (highestRisk > classConfig.maxToolRiskTier) warnings.push("toolset.risk_too_high");
  if (BigInt(input.bondAmount) < BigInt(classConfig.minLaunchBond)) warnings.push("bond.below_minimum");
  if (BigInt(input.initialFuelAmount) < BigInt(classConfig.minMemoryFuel)) warnings.push("fuel.below_minimum");

  return {
    classConfig,
    toolConfig,
    policyRoot,
    toolAllowlistRoot: input.toolSetRoot,
    initialMemoryRoot,
    activeGoalRoot,
    profileDigest,
    launchSpecRoot,
    warnings,
    valid: warnings.length === 0,
  };
}

export function buildPublicAgentLaunchIntent(
  input: PublicAgentLaunchInput,
  options: {
    operator?: string;
    rootfieldId: string;
    validAfter: string;
    validUntil: string;
    nonce: string;
    salt: string;
  },
): PublicAgentLaunchIntent {
  const preview = buildPublicAgentLaunchPreview(input);
  return {
    owner: input.owner,
    operator: options.operator ?? input.owner,
    classId: input.classId,
    rootfieldId: options.rootfieldId,
    kernelClass: preview.classConfig.kernelClass,
    policyRoot: preview.policyRoot,
    toolAllowlistRoot: preview.toolAllowlistRoot,
    initialMemoryRoot: preview.initialMemoryRoot,
    activeGoalRoot: preview.activeGoalRoot,
    profileDigest: preview.profileDigest,
    launchSpecRoot: preview.launchSpecRoot,
    autonomyLevel: input.autonomyLevel,
    riskLevel: input.riskLevel,
    parentAgentId: input.parentAgentId ?? "0x0000000000000000000000000000000000000000000000000000000000000000",
    parentSwarmId: input.parentSwarmId ?? "0x0000000000000000000000000000000000000000000000000000000000000000",
    bondToken: input.bondToken,
    bondAmount: input.bondAmount,
    fuelToken: input.fuelToken,
    initialFuelAmount: input.initialFuelAmount,
    discoverable: input.discoverable,
    validAfter: options.validAfter,
    validUntil: options.validUntil,
    nonce: options.nonce,
    salt: options.salt,
  };
}

export function hashPublicAgentLaunchIntent(intent: PublicAgentLaunchIntent): string {
  return stableRoot("flowmemory.public_agent.launch_intent.v1", intent);
}

export function buildPublicAgentLaunchContractHashes(
  intent: PublicAgentLaunchIntent,
  options: {
    chainId: string | number | bigint;
    verifyingContract: string;
    eip712Name?: string;
    eip712Version?: string;
  },
): PublicAgentLaunchContractHashes {
  const rootsHash = hashWords([
    encodeBytes32(intent.policyRoot),
    encodeBytes32(intent.toolAllowlistRoot),
    encodeBytes32(intent.initialMemoryRoot),
    encodeBytes32(intent.activeGoalRoot),
    encodeBytes32(intent.launchSpecRoot),
  ]);
  const configHash = hashWords([
    encodeBytes32(intent.profileDigest),
    encodeUint256(intent.autonomyLevel),
    encodeUint256(intent.riskLevel),
    encodeBool(intent.discoverable),
    encodeUint256(intent.validAfter),
    encodeUint256(intent.validUntil),
  ]);
  const lineageHash = hashWords([
    encodeBytes32(intent.parentAgentId),
    encodeBytes32(intent.parentSwarmId),
  ]);
  const fundingHash = hashWords([
    encodeAddress(intent.bondToken),
    encodeUint256(intent.bondAmount),
    encodeAddress(intent.fuelToken),
    encodeUint256(intent.initialFuelAmount),
  ]);
  const structHash = hashWords([
    encodeBytes32(LAUNCH_INTENT_TYPEHASH),
    encodeAddress(intent.owner),
    encodeAddress(intent.operator),
    encodeBytes32(intent.classId),
    encodeBytes32(intent.rootfieldId),
    encodeBytes32(intent.kernelClass),
    encodeBytes32(rootsHash),
    encodeBytes32(configHash),
    encodeBytes32(lineageHash),
    encodeBytes32(fundingHash),
    encodeUint256(intent.nonce),
    encodeBytes32(intent.salt),
  ]);
  const domainSeparator = hashWords([
    encodeBytes32(EIP712_DOMAIN_TYPEHASH),
    encodeBytes32(keccak256Utf8(options.eip712Name ?? "FlowMemory AgentFactory")),
    encodeBytes32(keccak256Utf8(options.eip712Version ?? "1")),
    encodeUint256(options.chainId),
    encodeAddress(options.verifyingContract),
  ]);
  const digest = keccak256Hex(concatBytes([
    EIP712_PREFIX,
    hexToBytes(domainSeparator),
    hexToBytes(structHash),
  ]));
  const launchId = hashWords([
    encodeUint256(options.chainId),
    encodeAddress(options.verifyingContract),
    encodeAddress(intent.owner),
    encodeBytes32(intent.classId),
    encodeBytes32(intent.policyRoot),
    encodeBytes32(intent.toolAllowlistRoot),
    encodeBytes32(intent.initialMemoryRoot),
    encodeBytes32(intent.activeGoalRoot),
    encodeBytes32(intent.profileDigest),
    encodeUint256(intent.nonce),
    encodeBytes32(intent.salt),
  ]);

  return {
    domainSeparator,
    rootsHash,
    configHash,
    lineageHash,
    fundingHash,
    structHash,
    digest,
    launchId,
  };
}

export function buildPrototypePublicAgentLaunchRecord(): PublicAgentLaunchRecord {
  const classConfig = DEFAULT_CLASSES[0]!;
  const input: PublicAgentLaunchInput = {
    owner: "0x1000000000000000000000000000000000000001",
    classId: classConfig.classId,
    objectiveText: "Launch a task scout",
    profileText: "Public task scout profile",
    toolSetRoot: DEFAULT_TOOLS[0]!.toolSetRoot,
    autonomyLevel: 2,
    riskLevel: 1,
    bondToken: "0x2000000000000000000000000000000000000001",
    bondAmount: classConfig.minLaunchBond,
    fuelToken: "0x2000000000000000000000000000000000000001",
    initialFuelAmount: classConfig.minMemoryFuel,
    discoverable: true,
  };
  const intent = buildPublicAgentLaunchIntent(input, {
    rootfieldId: keccak256Utf8("rootfield.public.task-scout.prototype"),
    validAfter: "1",
    validUntil: "2",
    nonce: "0",
    salt: keccak256Utf8("public-agent.prototype"),
  });
  return {
    launchId: stableRoot("flowmemory.public_agent.launch_id.v1", intent),
    agentId: stableRoot("flowmemory.public_agent.agent_id.v1", intent),
    owner: intent.owner,
    classId: intent.classId,
    className: classConfig.className,
    profileDigest: intent.profileDigest,
    policyRoot: intent.policyRoot,
    toolAllowlistRoot: intent.toolAllowlistRoot,
    initialMemoryRoot: intent.initialMemoryRoot,
    activeGoalRoot: intent.activeGoalRoot,
    bondToken: intent.bondToken,
    bondAmount: intent.bondAmount,
    fuelToken: intent.fuelToken,
    initialFuelAmount: intent.initialFuelAmount,
    discoverable: intent.discoverable,
  };
}
