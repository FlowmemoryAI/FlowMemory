#!/usr/bin/env node
import { spawn } from "node:child_process";
import { once } from "node:events";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { startControlPlaneServer } from "../../services/control-plane/src/server.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const CLI_PATH = resolve(REPO_ROOT, "services/flowmemory-sdk/src/cli.ts");

const COMMANDS = [
  { name: "public-agent-classes", schema: "flowmemory.control_plane.public_agent_class_list.v1" },
  { name: "public-agent-tools", schema: "flowmemory.control_plane.public_agent_tool_list.v1" },
  { name: "public-agent-launch", schema: "flowmemory.control_plane.public_agent_launch.v1" },
  { name: "public-agent-discover", schema: "flowmemory.control_plane.public_agent_discovery.v1" },
  { name: "public-swarm", schema: "flowmemory.control_plane.public_swarm.v1" },
  { name: "public-swarm-replay", schema: "flowmemory.control_plane.public_swarm_replay.v1" },
];

function excerpt(text, maxLines = 40) {
  const lines = text.split(/\r?\n/).filter((line) => line.length > 0);
  if (lines.length <= maxLines) return lines.join("\n");
  const head = lines.slice(0, Math.floor(maxLines / 2));
  const tail = lines.slice(lines.length - Math.ceil(maxLines / 2));
  return [...head, `... ${lines.length - maxLines} lines omitted ...`, ...tail].join("\n");
}

async function runCli(command, rpcUrl) {
  const started = Date.now();
  const child = spawn(process.execPath, [CLI_PATH, command.name, "--rpc", rpcUrl, "--json"], {
    cwd: REPO_ROOT,
    env: { ...process.env, NO_COLOR: "1", FORCE_COLOR: "0" },
    stdio: ["ignore", "pipe", "pipe"],
  });

  let stdout = "";
  let stderr = "";
  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  child.stdout.on("data", (chunk) => {
    stdout += chunk;
  });
  child.stderr.on("data", (chunk) => {
    stderr += chunk;
  });
  const [exitCode, signal] = await once(child, "close");
  const durationMs = Date.now() - started;
  const output = `${stdout}${stderr}`;

  if (exitCode !== 0) {
    return {
      command: command.name,
      status: "failed",
      durationMs,
      schema: null,
      excerpt: excerpt(output),
      reason: `exit code ${exitCode}${signal ? ` signal ${signal}` : ""}`,
    };
  }

  let parsed;
  try {
    parsed = JSON.parse(stdout);
  } catch (error) {
    return {
      command: command.name,
      status: "failed",
      durationMs,
      schema: null,
      excerpt: excerpt(output),
      reason: error instanceof Error ? error.message : String(error),
    };
  }

  if (parsed?.schema !== command.schema) {
    return {
      command: command.name,
      status: "failed",
      durationMs,
      schema: parsed?.schema ?? null,
      excerpt: excerpt(stdout),
      reason: `expected schema ${command.schema}`,
    };
  }

  return {
    command: command.name,
    status: "passed",
    durationMs,
    schema: parsed.schema,
    excerpt: "",
    reason: null,
  };
}

async function main() {
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });
  try {
    server.listen(0, "127.0.0.1");
    await once(server, "listening");
    const address = server.address();
    if (address === null || typeof address === "string") {
      throw new Error("control-plane server did not expose a numeric port");
    }
    const rpcUrl = `http://127.0.0.1:${address.port}/rpc`;
    const results = [];
    for (const command of COMMANDS) {
      results.push(await runCli(command, rpcUrl));
    }

    console.log(`FlowMemory public CLI smoke against ${rpcUrl}`);
    for (const result of results) {
      console.log(`- ${result.command}: ${result.status}${result.schema ? ` (${result.schema})` : ""}`);
      if (result.status !== "passed" && result.excerpt.length > 0) {
        console.log(result.excerpt);
      }
    }

    if (results.some((result) => result.status !== "passed")) {
      process.exitCode = 1;
    }
  } finally {
    server.close();
    await once(server, "close");
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
