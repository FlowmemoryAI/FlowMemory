import assert from "node:assert/strict";
import test from "node:test";

import {
  PUBLIC_AGENT_EVENT_CATALOG,
  buildReadbackReport,
  formatReadbackMarkdown,
  summarizePublicAgentLogs,
} from "./public-agent-network-base-sepolia-readback.mjs";

const contracts = {
  AgentClassRegistry: "0x1000000000000000000000000000000000000001",
  AgentFactory: "0x1000000000000000000000000000000000000002",
  AgentMemoryFuelVault: "0x1000000000000000000000000000000000000003",
  AgentLaunchBondEscrow: "0x1000000000000000000000000000000000000004",
  SwarmFactory: "0x1000000000000000000000000000000000000005",
};

function topic(name) {
  const event = PUBLIC_AGENT_EVENT_CATALOG.find((entry) => entry.name === name);
  assert.ok(event, `missing event ${name}`);
  return event.topic0;
}

function log({ event, address, blockNumber, logIndex, txHash }) {
  return {
    address,
    topics: [topic(event), "0x" + "00".repeat(32)],
    data: "0x",
    blockNumber: `0x${BigInt(blockNumber).toString(16)}`,
    transactionHash: txHash,
    transactionIndex: "0x0",
    logIndex: `0x${BigInt(logIndex).toString(16)}`,
    removed: false,
  };
}

test("summarizes required public-agent event groups", () => {
  const logs = [
    log({ event: "AgentClassRegistered", address: contracts.AgentClassRegistry, blockNumber: 7, logIndex: 0, txHash: "0xaaa" }),
    log({ event: "AgentLaunched", address: contracts.AgentFactory, blockNumber: 8, logIndex: 0, txHash: "0xbbb" }),
    log({ event: "FuelAccountRegistered", address: contracts.AgentMemoryFuelVault, blockNumber: 8, logIndex: 1, txHash: "0xbbb" }),
    log({ event: "LaunchBondLocked", address: contracts.AgentLaunchBondEscrow, blockNumber: 8, logIndex: 2, txHash: "0xbbb" }),
    log({ event: "SwarmLaunched", address: contracts.SwarmFactory, blockNumber: 9, logIndex: 0, txHash: "0xccc" }),
  ];

  const summary = summarizePublicAgentLogs({
    contracts,
    logs,
    txStatuses: {
      "0xaaa": "success",
      "0xbbb": "success",
      "0xccc": "success",
    },
  });

  assert.equal(summary.ok, true);
  assert.deepEqual(summary.missingRequiredGroups, []);
  assert.equal(summary.groupCounts.registry, 1);
  assert.equal(summary.groupCounts.launch, 1);
  assert.equal(summary.groupCounts.fuel, 1);
  assert.equal(summary.groupCounts.bond, 1);
  assert.equal(summary.groupCounts.swarm, 1);
  assert.equal(summary.observations[0].event, "AgentClassRegistered");
  assert.equal(summary.observations.at(-1).event, "SwarmLaunched");
});

test("readback report marks missing groups incomplete without inventing evidence", () => {
  const report = buildReadbackReport({
    generatedAt: "2026-05-21T00:00:00.000Z",
    deployerAddress: "0x69f55917209c446bf9d31d2903e01966b75a8cde",
    contracts,
    fromBlock: "1",
    toBlock: "10",
    maxBlockSpan: "10000",
    logs: [log({ event: "AgentClassRegistered", address: contracts.AgentClassRegistry, blockNumber: 7, logIndex: 0, txHash: "0xaaa" })],
    txStatuses: { "0xaaa": "success" },
  });

  assert.equal(report.ok, false);
  assert.deepEqual(report.missingRequiredGroups, ["launch", "fuel", "bond", "swarm"]);
  const markdown = formatReadbackMarkdown(report);
  assert.match(markdown, /Status: INCOMPLETE/);
  assert.match(markdown, /Base Sepolia readback only/);
});
