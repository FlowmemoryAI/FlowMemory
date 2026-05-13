import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { parseBaseCanaryReaderArgs, runBaseCanaryReader } from "../src/base-canary.ts";
import { parseBaseSepoliaReaderArgs, runBaseSepoliaReader } from "../src/base-sepolia.ts";
import { indexFlowPulseLogs, indexFlowPulseReceipts } from "../src/indexer.ts";
import { loadIndexerFixtureLogs, loadIndexerFixtureReceipts } from "../src/fixtures.ts";
import {
  indexerStateDigest,
  readBaseCanaryIndexerCheckpoint,
  readBaseSepoliaIndexerCheckpoint,
  readIndexerState,
  writeIndexerState,
} from "../src/persistence.ts";
import {
  readBaseMainnetCanaryFlowPulseLogs,
  readBaseSepoliaFlowPulseLogs,
  readLocalRpcFlowPulseLogs,
} from "../src/rpc.ts";

test("indexes FlowPulse fixture logs into canonical observations", () => {
  const state = indexFlowPulseLogs(loadIndexerFixtureLogs());
  assert.equal(state.schema, "flowmemory.indexer.state.v0");
  assert.equal(state.source, "fixture");
  assert.equal(state.observations.length, 1);
  assert.equal(state.observations[0].observationId, "0x9d958aadf8bf46f989b51e541709a73d21970e7e79643f939c9a0000b50f9a91");
  assert.equal(state.observations[0].lifecycleState, "observed");
  assert.equal(state.observations[0].duplicateKind, "unique");
  assert.equal(state.pulses.length, 1);
  assert.equal(state.rootfields.length, 1);
  assert.equal(state.dashboardFeed.schema, "flowmemory.indexer.dashboard_feed.v0");
  assert.equal(state.dashboardFeed.dashboardCanonicalObservationCount, 1);
  assert.equal(state.dashboardFeed.hasIntegrityWarnings, false);
});

test("detects exact duplicate observations", () => {
  const logs = loadIndexerFixtureLogs();
  const state = indexFlowPulseLogs([logs[0], logs[0]]);
  assert.equal(state.observations.length, 2);
  assert.equal(state.observations[1].duplicateKind, "exactDuplicate");
  assert.equal(state.duplicates.length, 1);
  assert.equal(state.dashboardFeed.duplicateKindCounts.exactDuplicate, 1);
  assert.equal(state.dashboardFeed.hasIntegrityWarnings, true);
});

test("ingests receipt fixtures and rejects reverted or malformed logs cleanly", () => {
  const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
    finalizedBlockNumber: "123458",
  });

  assert.equal(state.observations.length, 8);
  assert.equal(state.cursors.length, 7);
  assert.equal(state.batches[0].observationCount, 8);
  assert.equal(state.batches[0].cursorCount, 7);
  assert.equal(state.rejectedLogs.length, 2);
  assert.deepEqual(state.rejectedLogs.map((log) => log.reasonCode), ["receipt.reverted", "log.malformed"]);
  assert.equal(state.duplicates.length, 1);
  assert.equal(state.duplicates[0].kind, "exactDuplicate");
});

test("models finality threshold without claiming production reorg handling", () => {
  const [rootfieldReceipt, rootCommitReceipt] = loadIndexerFixtureReceipts();
  const state = indexFlowPulseReceipts([rootfieldReceipt, rootCommitReceipt], {
    finalizedBlockNumber: "123456",
  });

  assert.equal(state.observations[0].lifecycleState, "finalized");
  assert.equal(state.observations[1].lifecycleState, "pending");
});

test("marks block hash mismatches as reorged in fixture state", () => {
  const [, rootCommitReceipt] = loadIndexerFixtureReceipts();
  const state = indexFlowPulseReceipts([rootCommitReceipt], {
    canonicalBlockHashes: {
      "123457": "0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0",
    },
  });

  assert.equal(state.observations[0].lifecycleState, "reorged");
});

test("persists deterministic indexer state JSON", () => {
  const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
    finalizedBlockNumber: "123458",
  });
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-indexer-"));
  const path = join(dir, "state.json");

  try {
    writeIndexerState(path, state);
    const firstWrite = readFileSync(path, "utf8");
    writeIndexerState(path, state);
    const secondWrite = readFileSync(path, "utf8");
    const persisted = readIndexerState(path);

    assert.equal(firstWrite, secondWrite);
    assert.equal(persisted.schema, "flowmemory.indexer.persistence.v0");
    assert.equal(persisted.state.observations.length, 8);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("ships an indexer persistence JSON schema fixture", () => {
  const schemaPath = join(process.cwd(), "fixtures", "indexer-state.schema.json");
  const schema = JSON.parse(readFileSync(schemaPath, "utf8")) as { $id: string };
  assert.equal(schema.$id, "flowmemory.indexer.persistence.v0");
});

test("maps mocked local RPC logs into raw FlowPulse fixtures without secrets", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const calls: string[] = [];
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x2105" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({
        jsonrpc: "2.0",
        id: 1,
        result: [{
          address: fixtureLog.address,
          topics: fixtureLog.topics,
          data: fixtureLog.data,
          blockNumber: "0x1e240",
          blockHash: fixtureLog.blockHash,
          transactionHash: fixtureLog.transactionHash,
          transactionIndex: "0x7",
          logIndex: "0x2",
        }],
      });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: { status: "0x1" } });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  const logs = await readLocalRpcFlowPulseLogs({
    rpcUrl: "http://127.0.0.1:8545",
    addresses: [fixtureLog.address],
    fromBlock: "0x1e240",
    toBlock: "0x1e240",
    fetchImpl,
  });

  assert.deepEqual(calls, ["eth_chainId", "eth_getLogs", "eth_getTransactionReceipt"]);
  assert.equal(logs[0].chainId, "8453");
  assert.equal(logs[0].receiptStatus, "success");
  assert.equal(indexFlowPulseLogs(logs).observations[0].observationId, "0x9d958aadf8bf46f989b51e541709a73d21970e7e79643f939c9a0000b50f9a91");
});

test("rejects non Base Sepolia RPC endpoints for live reads", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const calls: string[] = [];
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x1" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: [] });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  await assert.rejects(
    () => readBaseSepoliaFlowPulseLogs({
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "0x1",
      toBlock: "0x2",
      fetchImpl,
    }),
    /expected Base Sepolia chainId 84532, received 1/,
  );
  assert.deepEqual(calls, ["eth_chainId"]);
});

test("rejects non Base mainnet RPC endpoints for canary reads", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const calls: string[] = [];
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x14a34" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: [] });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  await assert.rejects(
    () => readBaseMainnetCanaryFlowPulseLogs({
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "0x1",
      toBlock: "0x2",
      fetchImpl,
    }),
    /expected Base mainnet chainId 8453, received 84532/,
  );
  assert.deepEqual(calls, ["eth_chainId"]);
});

test("runs Base Sepolia reader and persists durable state plus checkpoint", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-"));
  const statePath = join(dir, "state.json");
  const checkpointPath = join(dir, "checkpoint.json");
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x14a34" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({
        jsonrpc: "2.0",
        id: 1,
        result: [{
          address: fixtureLog.address,
          topics: fixtureLog.topics,
          data: fixtureLog.data,
          blockNumber: "0x1e240",
          blockHash: fixtureLog.blockHash,
          transactionHash: fixtureLog.transactionHash,
          transactionIndex: "0x7",
          logIndex: "0x2",
        }],
      });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: { status: "0x1" } });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  try {
    const result = await runBaseSepoliaReader({
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "123456",
      toBlock: "123456",
      finalizedBlockNumber: "123456",
      outPath: statePath,
      checkpointPath,
      generatedAt: "2026-05-13T00:00:00.000Z",
      fetchImpl,
    });
    const persisted = readIndexerState(statePath);
    const checkpoint = readBaseSepoliaIndexerCheckpoint(checkpointPath);

    assert.equal(result.state.source, "base-sepolia-rpc");
    assert.equal(persisted.state.source, "base-sepolia-rpc");
    assert.equal(persisted.state.observations[0].lifecycleState, "finalized");
    assert.equal(checkpoint.schema, "flowmemory.indexer.base_sepolia_checkpoint.v0");
    assert.equal(checkpoint.network, "base-sepolia");
    assert.equal(checkpoint.chainId, "84532");
    assert.equal(checkpoint.lastIndexedBlock, "123456");
    assert.equal(checkpoint.lastScannedBlock, "123456");
    assert.equal(checkpoint.highestObservedBlock, "123456");
    assert.equal(checkpoint.nextFromBlock, "123457");
    assert.equal(checkpoint.emptyRange, false);
    assert.equal(checkpoint.stateDigest, indexerStateDigest(result.state));
    assert.equal(checkpoint.dashboardFeed.dashboardCanonicalObservationCount, 1);
    assert.equal(checkpoint.safety.productionReady, false);
    assert.equal(checkpoint.safety.storesRpcUrl, false);
    assert.equal(checkpoint.observationCount, 1);
    assert.equal(checkpoint.statePath, statePath);
    assert.equal(readFileSync(statePath, "utf8").includes("example.invalid"), false);
    assert.equal(readFileSync(checkpointPath, "utf8").includes("example.invalid"), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("Base Sepolia reader records RPC and ABI malformed logs in the dashboard feed", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-malformed-"));
  const statePath = join(dir, "state.json");
  const checkpointPath = join(dir, "checkpoint.json");
  const calls: string[] = [];
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x14a34" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({
        jsonrpc: "2.0",
        id: 1,
        result: [
          {
            address: fixtureLog.address,
            topics: "not-an-array",
            data: fixtureLog.data,
            blockNumber: "0x1e240",
            blockHash: fixtureLog.blockHash,
            transactionHash: fixtureLog.transactionHash,
            transactionIndex: "0x0",
            logIndex: "0x0",
          },
          {
            address: fixtureLog.address,
            topics: fixtureLog.topics.slice(0, 3),
            data: fixtureLog.data,
            blockNumber: "0x1e240",
            blockHash: fixtureLog.blockHash,
            transactionHash: fixtureLog.transactionHash,
            transactionIndex: "0x1",
            logIndex: "0x1",
          },
          {
            address: fixtureLog.address,
            topics: fixtureLog.topics,
            data: fixtureLog.data,
            blockNumber: "0x1e240",
            blockHash: fixtureLog.blockHash,
            transactionHash: fixtureLog.transactionHash,
            transactionIndex: "0x2",
            logIndex: "0x2",
          },
        ],
      });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: { status: "0x1" } });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  try {
    const result = await runBaseSepoliaReader({
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "123456",
      toBlock: "123456",
      outPath: statePath,
      checkpointPath,
      generatedAt: "2026-05-13T00:00:00.000Z",
      fetchImpl,
    });
    const checkpoint = readBaseSepoliaIndexerCheckpoint(checkpointPath);

    assert.deepEqual(calls, [
      "eth_chainId",
      "eth_getLogs",
      "eth_getTransactionReceipt",
      "eth_getTransactionReceipt",
    ]);
    assert.equal(result.state.observations.length, 1);
    assert.equal(result.state.rejectedLogs.length, 2);
    assert.deepEqual(result.state.rejectedLogs.map((log) => log.reasonCode), [
      "rpc.log.malformed",
      "log.malformed",
    ]);
    assert.equal(result.state.dashboardFeed.rejectedReasonCounts["rpc.log.malformed"], 1);
    assert.equal(result.state.dashboardFeed.rejectedReasonCounts["log.malformed"], 1);
    assert.equal(checkpoint.dashboardFeed.hasIntegrityWarnings, true);
    assert.equal(checkpoint.dashboardFeed.rejectedLogCount, 2);
    assert.equal(checkpoint.emptyRange, false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("runs Base mainnet canary reader and persists empty scans safely", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-canary-empty-"));
  const statePath = join(dir, "state.json");
  const checkpointPath = join(dir, "checkpoint.json");
  const calls: string[] = [];
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x2105" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: [] });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  try {
    const result = await runBaseCanaryReader({
      acknowledgeMainnetCanary: true,
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "45955500",
      toBlock: "45955500",
      finalizedBlockNumber: "45955500",
      outPath: statePath,
      checkpointPath,
      generatedAt: "2026-05-13T00:00:00.000Z",
      fetchImpl,
    });
    const persisted = readIndexerState(statePath);
    const checkpoint = readBaseCanaryIndexerCheckpoint(checkpointPath);

    assert.deepEqual(calls, ["eth_chainId", "eth_getLogs"]);
    assert.equal(result.state.source, "base-mainnet-canary-rpc");
    assert.equal(persisted.state.source, "base-mainnet-canary-rpc");
    assert.equal(checkpoint.schema, "flowmemory.indexer.base_canary_checkpoint.v0");
    assert.equal(checkpoint.network, "base-mainnet-canary");
    assert.equal(checkpoint.chainId, "8453");
    assert.equal(checkpoint.safety.productionReady, false);
    assert.equal(checkpoint.observationCount, 0);
    assert.equal(checkpoint.rejectedLogCount, 0);
    assert.equal(checkpoint.lastIndexedBlock, "45955500");
    assert.equal(checkpoint.highestObservedBlock, null);
    assert.equal(checkpoint.nextFromBlock, "45955501");
    assert.equal(checkpoint.emptyRange, true);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("Base mainnet canary reader surfaces malformed logs without dropping checkpoints", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-canary-malformed-"));
  const statePath = join(dir, "state.json");
  const checkpointPath = join(dir, "checkpoint.json");
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x2105" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({
        jsonrpc: "2.0",
        id: 1,
        result: [{
          address: fixtureLog.address,
          topics: fixtureLog.topics.slice(0, 3),
          data: fixtureLog.data,
          blockNumber: "0x2bd270c",
          blockHash: fixtureLog.blockHash,
          transactionHash: fixtureLog.transactionHash,
          transactionIndex: "0x0",
          logIndex: "0x0",
        }],
      });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: { status: "0x1" } });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  try {
    const result = await runBaseCanaryReader({
      acknowledgeMainnetCanary: true,
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "45950732",
      toBlock: "45950732",
      outPath: statePath,
      checkpointPath,
      generatedAt: "2026-05-13T00:00:00.000Z",
      fetchImpl,
    });
    const checkpoint = readBaseCanaryIndexerCheckpoint(checkpointPath);

    assert.equal(result.state.observations.length, 0);
    assert.equal(result.state.rejectedLogs.length, 1);
    assert.equal(result.state.rejectedLogs[0].reasonCode, "log.malformed");
    assert.equal(checkpoint.rejectedLogCount, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("Base mainnet canary reader preserves exact duplicates and reorg replacements", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-canary-duplicates-"));
  const statePath = join(dir, "state.json");
  const checkpointPath = join(dir, "checkpoint.json");
  const reorgLog = {
    address: fixtureLog.address,
    topics: fixtureLog.topics,
    data: fixtureLog.data,
    blockNumber: "0x2bd270d",
    blockHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
    transactionHash: "0x2222222222222222222222222222222222222222222222222222222222222222",
    transactionIndex: "0x1",
    logIndex: "0x0",
  };
  const baseLog = {
    address: fixtureLog.address,
    topics: fixtureLog.topics,
    data: fixtureLog.data,
    blockNumber: "0x2bd270c",
    blockHash: fixtureLog.blockHash,
    transactionHash: fixtureLog.transactionHash,
    transactionIndex: "0x0",
    logIndex: "0x0",
  };
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x2105" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: [baseLog, baseLog, reorgLog] });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: { status: "0x1" } });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  try {
    const result = await runBaseCanaryReader({
      acknowledgeMainnetCanary: true,
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "45950732",
      toBlock: "45950733",
      outPath: statePath,
      checkpointPath,
      generatedAt: "2026-05-13T00:00:00.000Z",
      fetchImpl,
    });

    assert.equal(result.state.observations.length, 3);
    assert.deepEqual(result.state.duplicates.map((duplicate) => duplicate.kind), [
      "exactDuplicate",
      "reorgReplacement",
    ]);
    assert.equal(result.checkpoint.duplicateCount, 2);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("parses Base Sepolia reader CLI args without defaulting to a public RPC", () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const parsed = parseBaseSepoliaReaderArgs([
    "--rpc-url",
    "https://example.invalid",
    "--address",
    fixtureLog.address,
    "--from-block",
    "0x1e240",
    "--to-block",
    "123456",
    "--finalized-block",
    "0x1e240",
  ]);

  assert.equal(parsed.fromBlock, "123456");
  assert.equal(parsed.toBlock, "123456");
  assert.equal(parsed.finalizedBlockNumber, "123456");
  assert.equal(parsed.addresses[0], fixtureLog.address.toLowerCase());
  assert.throws(
    () => parseBaseSepoliaReaderArgs(["--address", fixtureLog.address, "--from-block", "1", "--to-block", "2"]),
    /--rpc-url is required/,
  );
  assert.throws(
    () => parseBaseSepoliaReaderArgs([
      "--rpc-url",
      "$BASE_SEPOLIA_RPC_URL",
      "--address",
      fixtureLog.address,
      "--from-block",
      "1",
      "--to-block",
      "2",
    ]),
    /resolved URL/,
  );
  assert.throws(
    () => parseBaseSepoliaReaderArgs([
      "--rpc-url",
      "https://user:pass@example.invalid",
      "--address",
      fixtureLog.address,
      "--from-block",
      "1",
      "--to-block",
      "2",
    ]),
    /username\/password credentials/,
  );
  assert.throws(
    () => parseBaseSepoliaReaderArgs([
      "--rpc-url",
      "https://example.invalid",
      "--address",
      fixtureLog.address,
      "--from-block",
      "1",
      "--to-block",
      "10002",
    ]),
    /refuses broad scans/,
  );
});

test("Base Sepolia reader supports safe checkpoint resume after empty ranges", async () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-resume-"));
  const statePath = join(dir, "state.json");
  const checkpointPath = join(dir, "checkpoint.json");
  const fetchImpl = async (_url: string, init?: RequestInit): Promise<Response> => {
    const body = JSON.parse(String(init?.body)) as { method: string };
    if (body.method === "eth_chainId") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: "0x14a34" });
    }
    if (body.method === "eth_getLogs") {
      return Response.json({ jsonrpc: "2.0", id: 1, result: [] });
    }
    return Response.json({ jsonrpc: "2.0", id: 1, error: { code: -32601, message: "not found" } });
  };

  try {
    const result = await runBaseSepoliaReader({
      rpcUrl: "https://example.invalid",
      addresses: [fixtureLog.address],
      fromBlock: "123456",
      toBlock: "123460",
      outPath: statePath,
      checkpointPath,
      generatedAt: "2026-05-13T00:00:00.000Z",
      fetchImpl,
    });

    assert.equal(result.checkpoint.observationCount, 0);
    assert.equal(result.checkpoint.lastIndexedBlock, "123460");
    assert.equal(result.checkpoint.nextFromBlock, "123461");
    assert.equal(result.checkpoint.emptyRange, true);

    const parsed = parseBaseSepoliaReaderArgs([
      "--rpc-url",
      "https://example.invalid",
      "--address",
      fixtureLog.address,
      "--resume-from-checkpoint",
      "--checkpoint-out",
      checkpointPath,
      "--to-block",
      "123470",
    ]);

    assert.equal(parsed.fromBlock, "123461");
    assert.equal(parsed.toBlock, "123470");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("parses guarded Base mainnet canary reader CLI args", () => {
  const [fixtureLog] = loadIndexerFixtureLogs();
  const parsed = parseBaseCanaryReaderArgs([
    "--acknowledge-mainnet-canary",
    "--rpc-url",
    "https://example.invalid",
    "--addresses",
    `${fixtureLog.address},${fixtureLog.address.toUpperCase()}`,
    "--from-block",
    "0x2bd270c",
    "--to-block",
    "45950740",
    "--finalized-block",
    "0x2bd270c",
  ]);

  assert.equal(parsed.fromBlock, "45950732");
  assert.equal(parsed.toBlock, "45950740");
  assert.equal(parsed.finalizedBlockNumber, "45950732");
  assert.equal(parsed.addresses.length, 1);
  assert.equal(parsed.acknowledgeMainnetCanary, true);
  assert.throws(
    () => parseBaseCanaryReaderArgs([
      "--rpc-url",
      "https://example.invalid",
      "--address",
      fixtureLog.address,
      "--from-block",
      "1",
      "--to-block",
      "2",
    ]),
    /--acknowledge-mainnet-canary is required/,
  );
  assert.throws(
    () => parseBaseCanaryReaderArgs([
      "--acknowledge-mainnet-canary",
      "--rpc-url",
      "https://example.invalid",
      "--address",
      fixtureLog.address,
      "--from-block",
      "1",
      "--to-block",
      "5002",
    ]),
    /refuses broad scans/,
  );
});
