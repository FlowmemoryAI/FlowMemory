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

export const PUBLIC_AGENT_CLASSES: PublicAgentClassConfig[] = [
  {
    classId: "0x94ce5eb8ef6235b8c867de9e909f96cf185f98fdc91d7aeb24b8cf924871c744",
    className: "Task Scout",
    version: 1,
    kernelClass: "0x4c46ee814081fc7ac88830d64b092a026d5f5beafec1aa9c01666c161d5e7393",
    minAutonomyLevel: 1,
    maxAutonomyLevel: 3,
    maxToolRiskTier: 2,
    maxTools: 4,
    minLaunchBond: "10000000000000000000",
    minMemoryFuel: "5000000000000000000",
    allowPublicLaunch: true,
    allowSwarmMembership: true,
    allowShellGraduation: false,
    metadataDigest: "0x4cbf58384e278d3fe39863d773cb1cc7d40a3dd2340d30a8f8fdf7936a6fdcf3",
  },
  {
    classId: "0x02855bc9276276d715f194cc5505dd2b4f55b5c581c2a4c0aee38f7ff5fbd0fc",
    className: "Research Synth Agent",
    version: 1,
    kernelClass: "0x508f8bc8de5f6f79031fdb1b51e36bd4f353f9841763d03dd32e4f570d00f3f4",
    minAutonomyLevel: 1,
    maxAutonomyLevel: 2,
    maxToolRiskTier: 1,
    maxTools: 3,
    minLaunchBond: "15000000000000000000",
    minMemoryFuel: "7000000000000000000",
    allowPublicLaunch: true,
    allowSwarmMembership: true,
    allowShellGraduation: false,
    metadataDigest: "0x2cb4246473510624aa4e6da37ae5d980f83a737368a6e3f432a2f831be5d0f53",
  },
  {
    classId: "0x6142ac4b182f447f84d7ca7b3d5235cbf27175af2c3ac7b0f2808d6d91945bfd",
    className: "Swarm Coordinator",
    version: 1,
    kernelClass: "0x8b2f842b78d478a5da6e14f6698f6bd290ef5137df9f72b7af55fa765381753d",
    minAutonomyLevel: 2,
    maxAutonomyLevel: 4,
    maxToolRiskTier: 3,
    maxTools: 6,
    minLaunchBond: "25000000000000000000",
    minMemoryFuel: "10000000000000000000",
    allowPublicLaunch: true,
    allowSwarmMembership: true,
    allowShellGraduation: true,
    metadataDigest: "0xb0d0088b9b3a2e4f3bd59b9bf0ed81e4e40a5405944c0ab5d2ebd3b70df4db22",
  },
];

export const PUBLIC_AGENT_TOOLS: PublicToolConfig[] = [
  {
    toolId: "0x7fd3119b0cfcac0f3203066db68f9f19bc8abfe13b22c599b99bcf6f17ab4fcb",
    toolName: "Task Accept",
    toolSetRoot: "0xd6717d12f7068dbdbdfd4e9444d1aadf133b650aeb92fa44f2c1667af14e3c94",
    riskTier: 2,
    mutating: true,
    requiresDryRun: true,
    requiresHumanConfirm: false,
    metadataDigest: "0x476243194b16a4a957ddf4e4e7ebcd5075256cdaf54ab9d37f9b88b478ec7340",
  },
  {
    toolId: "0xf7f6e2f7c154cca8428270dc6943940c697c57d5c3aa76d7f99f9145f674a751",
    toolName: "Memory Only Update",
    toolSetRoot: "0x558f1ea4f613d95650544d44b2467cf641f5f4e1ca7f30b3e16d67fc596a6499",
    riskTier: 1,
    mutating: true,
    requiresDryRun: false,
    requiresHumanConfirm: false,
    metadataDigest: "0xa2f5bca7625a79049fc771f2980a694accc0c5316fb8f1ebf8a7c6b6a1ed5ef7",
  },
  {
    toolId: "0x6bac299122ba75847d8cb4cb97c7a9924aec676e32f4d7b007d094c0fd539221",
    toolName: "Swarm Join",
    toolSetRoot: "0x389a6e7247a02c57fd38dcd4cbf3d8ff6a3fa0be9370d79375967417c87d011d",
    riskTier: 3,
    mutating: true,
    requiresDryRun: true,
    requiresHumanConfirm: true,
    metadataDigest: "0x580fb5843a3be19088a8cd1f3c48d5af23bd330627d354c66a6bc09e90c22cdc",
  },
];
