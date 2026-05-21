import assert from "node:assert/strict";
import test from "node:test";

import {
  buildPublicAgentLaunchIntent,
  buildPublicAgentLaunchPreview,
  buildPublicAgentLaunchContractHashes,
  hashPublicAgentLaunchIntent,
  listPublicAgentClasses,
} from "../src/public-agent-network.ts";
import {
  buildPublicSwarmLaunchIntent,
  buildPublicSwarmLaunchPreview,
  buildPublicSwarmLaunchContractHashes,
  hashPublicSwarmLaunchIntent,
  listPublicSwarmClasses,
} from "../src/public-swarm-network.ts";
import { keccak256Utf8 } from "../../shared/src/index.ts";

test("builds deterministic public agent launch preview and intent", () => {
  const classConfig = listPublicAgentClasses()[0];
  assert.ok(classConfig);
  const preview = buildPublicAgentLaunchPreview({
    owner: "0x1000000000000000000000000000000000000001",
    classId: classConfig.classId,
    objectiveText: "Launch a task scout",
    profileText: "Public task scout profile",
    toolSetRoot: "0xd6717d12f7068dbdbdfd4e9444d1aadf133b650aeb92fa44f2c1667af14e3c94",
    autonomyLevel: 2,
    riskLevel: 1,
    bondToken: "0x2000000000000000000000000000000000000001",
    bondAmount: "10000000000000000000",
    fuelToken: "0x2000000000000000000000000000000000000001",
    initialFuelAmount: "5000000000000000000",
    discoverable: true,
  });
  assert.equal(preview.valid, true);
  const intent = buildPublicAgentLaunchIntent(
    {
      owner: "0x1000000000000000000000000000000000000001",
      classId: classConfig.classId,
      objectiveText: "Launch a task scout",
      profileText: "Public task scout profile",
      toolSetRoot: "0xd6717d12f7068dbdbdfd4e9444d1aadf133b650aeb92fa44f2c1667af14e3c94",
      autonomyLevel: 2,
      riskLevel: 1,
      bondToken: "0x2000000000000000000000000000000000000001",
      bondAmount: "10000000000000000000",
      fuelToken: "0x2000000000000000000000000000000000000001",
      initialFuelAmount: "5000000000000000000",
      discoverable: true,
    },
    {
      rootfieldId: keccak256Utf8("rootfield.public.task-scout.alpha"),
      validAfter: "1",
      validUntil: "2",
      nonce: "0",
      salt: keccak256Utf8("launch.alpha"),
    },
  );
  assert.equal(intent.policyRoot, preview.policyRoot);
  assert.equal(hashPublicAgentLaunchIntent(intent).startsWith("0x"), true);
  const contractHashes = buildPublicAgentLaunchContractHashes(intent, {
    chainId: 31337,
    verifyingContract: "0x3000000000000000000000000000000000000003",
  });
  assert.equal(contractHashes.digest.startsWith("0x"), true);
  assert.equal(contractHashes.digest.length, 66);
  assert.equal(contractHashes.launchId.length, 66);
});

test("builds deterministic public swarm preview", () => {
  const swarmClass = listPublicSwarmClasses()[0];
  assert.ok(swarmClass);
  const preview = buildPublicSwarmLaunchPreview({
    creator: "0x1000000000000000000000000000000000000001",
    swarmClass: swarmClass.swarmClass,
    missionText: "Research a launch opportunity",
    profileText: "Research swarm profile",
    budgetAsset: "0x2000000000000000000000000000000000000001",
    initialBudget: "1000000000000000000",
  });
  const intent = buildPublicSwarmLaunchIntent(
    {
      creator: "0x1000000000000000000000000000000000000001",
      swarmClass: swarmClass.swarmClass,
      missionText: "Research a launch opportunity",
      profileText: "Research swarm profile",
      budgetAsset: "0x2000000000000000000000000000000000000001",
      initialBudget: "1000000000000000000",
    },
    {
      validAfter: "1",
      validUntil: "2",
      nonce: "0",
      salt: keccak256Utf8("swarm.alpha"),
    },
  );
  assert.equal(preview.valid, true);
  assert.equal(preview.warnings.length, 0);
  assert.equal(intent.missionRoot, preview.missionRoot);
  assert.equal(hashPublicSwarmLaunchIntent(intent).startsWith("0x"), true);
  const contractHashes = buildPublicSwarmLaunchContractHashes(intent, {
    chainId: 31337,
    factory: "0x3000000000000000000000000000000000000003",
  });
  assert.equal(contractHashes.intentHash.startsWith("0x"), true);
  assert.equal(contractHashes.swarmId.length, 66);
});
