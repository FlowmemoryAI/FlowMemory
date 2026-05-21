import { canonicalJson, encodeAddress, encodeBytes32, encodeUint256, keccak256Hex, keccak256Utf8 } from "../../shared/src/index.ts";

export interface PublicSwarmClassConfig {
  swarmClass: string;
  name: string;
  maxMembers: number;
  maxMemberRiskTier: number;
  budgetAssetPolicy: string;
  active: boolean;
}

export interface PublicSwarmLaunchInput {
  creator: string;
  swarmClass: string;
  missionText: string;
  profileText: string;
  budgetAsset: string;
  initialBudget: string;
  parentSwarmId?: string;
}

export interface PublicSwarmLaunchIntent {
  creator: string;
  swarmClass: string;
  missionRoot: string;
  sharedMemoryRoot: string;
  policyRoot: string;
  roleRoot: string;
  profileDigest: string;
  budgetAsset: string;
  initialBudget: string;
  validAfter: string;
  validUntil: string;
  nonce: string;
  parentSwarmId: string;
  salt: string;
}


export interface PublicSwarmRecord {
  swarmId: string;
  swarmClass: string;
  name: string;
  missionRoot: string;
  sharedMemoryRoot: string;
  policyRoot: string;
  roleRoot: string;
  profileDigest: string;
  budgetAsset: string;
  initialBudget: string;
}
export interface PublicSwarmLaunchPreview {
  classConfig: PublicSwarmClassConfig;
  missionRoot: string;
  sharedMemoryRoot: string;
  policyRoot: string;
  roleRoot: string;
  profileDigest: string;
  warnings: string[];
  valid: boolean;
}

export interface PublicSwarmLaunchContractHashes {
  intentHash: string;
  swarmId: string;
}

const SWARM_CLASSES: PublicSwarmClassConfig[] = [
  {
    swarmClass: keccak256Utf8("RESEARCH_SWARM_V0"),
    name: "Research Swarm",
    maxMembers: 10,
    maxMemberRiskTier: 2,
    budgetAssetPolicy: "token-or-usdc",
    active: true,
  },
  {
    swarmClass: keccak256Utf8("MEDIA_SWARM_V0"),
    name: "Media Swarm",
    maxMembers: 12,
    maxMemberRiskTier: 2,
    budgetAssetPolicy: "token-or-usdc",
    active: true,
  },
  {
    swarmClass: keccak256Utf8("TASK_MARKET_SWARM_V0"),
    name: "Task Market Swarm",
    maxMembers: 16,
    maxMemberRiskTier: 3,
    budgetAssetPolicy: "usdc-preferred",
    active: true,
  },
  {
    swarmClass: keccak256Utf8("GOVERNANCE_ANALYSIS_SWARM_V0"),
    name: "Governance Analysis Swarm",
    maxMembers: 8,
    maxMemberRiskTier: 1,
    budgetAssetPolicy: "token-or-usdc",
    active: true,
  },
];

function stableRoot(schema: string, value: unknown): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value } as Record<string, unknown>)));
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

function hashWords(parts: Uint8Array[]): string {
  return keccak256Hex(concatBytes(parts));
}

export function listPublicSwarmClasses(): PublicSwarmClassConfig[] {
  return [...SWARM_CLASSES];
}

export function getPublicSwarmClass(swarmClass: string): PublicSwarmClassConfig | null {
  return SWARM_CLASSES.find((entry) => entry.swarmClass === swarmClass) ?? null;
}

export function buildPublicSwarmLaunchPreview(input: PublicSwarmLaunchInput): PublicSwarmLaunchPreview {
  const classConfig = getPublicSwarmClass(input.swarmClass);
  if (classConfig === null) {
    throw new Error(`unknown public swarm class: ${input.swarmClass}`);
  }
  const missionRoot = stableRoot("flowmemory.public_swarm.mission.v1", input.missionText);
  const sharedMemoryRoot = stableRoot("flowmemory.public_swarm.shared_memory.v1", {
    missionText: input.missionText,
    parentSwarmId: input.parentSwarmId ?? null,
  });
  const policyRoot = stableRoot("flowmemory.public_swarm.policy.v1", {
    swarmClass: input.swarmClass,
    budgetAsset: input.budgetAsset,
  });
  const roleRoot = stableRoot("flowmemory.public_swarm.roles.v1", input.swarmClass);
  const profileDigest = stableRoot("flowmemory.public_swarm.profile.v1", input.profileText);
  const warnings: string[] = [];
  if (!classConfig.active) warnings.push("swarm.class.inactive");
  if (BigInt(input.initialBudget) == 0n) warnings.push("swarm.initial_budget.zero");
  return {
    classConfig,
    missionRoot,
    sharedMemoryRoot,
    policyRoot,
    roleRoot,
    profileDigest,
    warnings,
    valid: warnings.length === 0,
  };
}

export function buildPublicSwarmLaunchIntent(
  input: PublicSwarmLaunchInput,
  options: {
    validAfter: string;
    validUntil: string;
    nonce: string;
    salt: string;
  },
): PublicSwarmLaunchIntent {
  const preview = buildPublicSwarmLaunchPreview(input);
  return {
    creator: input.creator,
    swarmClass: input.swarmClass,
    missionRoot: preview.missionRoot,
    sharedMemoryRoot: preview.sharedMemoryRoot,
    policyRoot: preview.policyRoot,
    roleRoot: preview.roleRoot,
    profileDigest: preview.profileDigest,
    budgetAsset: input.budgetAsset,
    initialBudget: input.initialBudget,
    validAfter: options.validAfter,
    validUntil: options.validUntil,
    nonce: options.nonce,
    parentSwarmId: input.parentSwarmId ?? "0x0000000000000000000000000000000000000000000000000000000000000000",
    salt: options.salt,
  };
}

export function hashPublicSwarmLaunchIntent(intent: PublicSwarmLaunchIntent): string {
  return stableRoot("flowmemory.public_swarm.launch_intent.v1", intent);
}

export function buildPublicSwarmLaunchContractHashes(
  intent: PublicSwarmLaunchIntent,
  options: {
    chainId: string | number | bigint;
    factory: string;
  },
): PublicSwarmLaunchContractHashes {
  const intentHash = hashWords([
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
  ]);
  const swarmId = hashWords([
    encodeUint256(options.chainId),
    encodeAddress(options.factory),
    encodeAddress(intent.creator),
    encodeBytes32(intent.swarmClass),
    encodeBytes32(intent.missionRoot),
    encodeBytes32(intent.sharedMemoryRoot),
    encodeUint256(intent.nonce),
    encodeBytes32(intent.salt),
  ]);

  return { intentHash, swarmId };
}

export function buildPrototypePublicSwarmRecord(): PublicSwarmRecord {
  const classConfig = SWARM_CLASSES[0]!;
  const input: PublicSwarmLaunchInput = {
    creator: "0x1000000000000000000000000000000000000001",
    swarmClass: classConfig.swarmClass,
    missionText: "Research a launch opportunity",
    profileText: "Research swarm profile",
    budgetAsset: "0x2000000000000000000000000000000000000001",
    initialBudget: "1000000000000000000",
  };
  const intent = buildPublicSwarmLaunchIntent(input, {
    validAfter: "1",
    validUntil: "2",
    nonce: "0",
    salt: keccak256Utf8("public-swarm.prototype"),
  });
  return {
    swarmId: stableRoot("flowmemory.public_swarm.id.v1", intent),
    swarmClass: intent.swarmClass,
    name: classConfig.name,
    missionRoot: intent.missionRoot,
    sharedMemoryRoot: intent.sharedMemoryRoot,
    policyRoot: intent.policyRoot,
    roleRoot: intent.roleRoot,
    profileDigest: intent.profileDigest,
    budgetAsset: intent.budgetAsset,
    initialBudget: intent.initialBudget,
  };
}
