import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { parseBaseSepoliaReaderArgs, runBaseSepoliaReader } from "../src/base-sepolia.ts";
import { indexFlowPulseLogs, indexFlowPulseReceipts } from "../src/indexer.ts";
import { loadIndexerFixtureLogs, loadIndexerFixtureReceipts } from "../src/fixtures.ts";
import { readBaseSepoliaIndexerCheckpoint, readIndexerState, writeIndexerState } from "../src/persistence.ts";
import { readBaseSepoliaFlowPulseLogs, readLocalRpcFlowPulseLogs } from "../src/rpc.ts";

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
});

test("detects exact duplicate observations", () => {
  const logs = loadIndexerFixtureLogs();
  const state = indexFlowPulseLogs([logs[0], logs[0]]);
  assert.equal(state.observations.length, 2);
  assert.equal(state.observations[1].duplicateKind, "exactDuplicate");
  assert.equal(state.duplicates.length, 1);
});

test("ingests receipt fixtures and rejects reverted or malformed logs cleanly", () => {
  const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
    finalizedBlockNumber: "123458",
  });

  assert.equal(state.observations.length, 7);
  assert.equal(state.cursors.length, 6);
  assert.equal(state.batches[0].observationCount, 7);
  assert.equal(state.batches[0].cursorCount, 6);
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
    assert.equal(persisted.state.observations.length, 7);
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
    assert.equal(checkpoint.observationCount, 1);
    assert.equal(checkpoint.statePath, statePath);
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
});
