#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const args = process.argv.slice(2);
const flags = new Set(args.filter((arg) => arg.startsWith("--")));

function valueAfter(flag, fallback) {
  const index = args.indexOf(flag);
  if (index === -1) return fallback;
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${flag} requires a value`);
  }
  return value;
}

const deploymentPath = valueAfter("--deployment", "fixtures/deployments/base-canary-v0.json");
const reportPath = valueAfter("--report", "fixtures/deployments/base-canary-source-verification-plan.json");
const rpcUrl = valueAfter("--rpc-url", process.env.BASE_CANARY_RPC_URL ?? "https://mainnet.base.org");
const submit = flags.has("--submit");
const json = flags.has("--json");
const watch = flags.has("--watch");
const checkBytecode = flags.has("--check-bytecode");
const continueOnError = flags.has("--continue-on-error");
const delayMs = Number(valueAfter("--delay-ms", "0"));
const artifact = JSON.parse(readFileSync(resolve(deploymentPath), "utf8"));

if (artifact.schema !== "flowmemory.deployment_artifact.v0") {
  throw new Error(`unsupported deployment artifact schema: ${artifact.schema}`);
}
if (artifact.productionReady !== false || artifact.status !== "canary-only") {
  throw new Error("source verification script only accepts canary-only deployment artifacts");
}
if (artifact.network?.chainId !== "8453") {
  throw new Error(`expected Base mainnet chain id 8453, received ${artifact.network?.chainId}`);
}

const apiKeyEnv = artifact.sourceVerification?.apiKeyEnv ?? "BASESCAN_API_KEY";
const apiKey = process.env[apiKeyEnv];
if (submit && !apiKey) {
  throw new Error(`${apiKeyEnv} is required when --submit is used`);
}

function verificationArgs(contract, apiKeyValue) {
  const sourceVerification = artifact.sourceVerification;
  const result = [
    "verify-contract",
    contract.address,
    contract.sourceName,
    "--chain-id",
    sourceVerification.chainId,
    "--compiler-version",
    sourceVerification.compilerVersion,
    "--num-of-optimizations",
    String(sourceVerification.optimizerRuns),
    "--verifier",
    sourceVerification.verifier,
    "--etherscan-api-key",
    apiKeyValue,
  ];
  if (watch) {
    result.push("--watch");
  }
  return result;
}

function redact(value) {
  if (!apiKey) return value;
  return value.replaceAll(apiKey, `<${apiKeyEnv}>`);
}

function redactArgs(commandArgs) {
  return commandArgs.map((arg) => redact(arg));
}

function sleep(milliseconds) {
  if (milliseconds <= 0) return;
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function run(command, commandArgs) {
  const result = spawnSync(command, commandArgs, {
    cwd: process.cwd(),
    stdio: "inherit",
  });
  if (result.status !== 0) {
    throw new Error(`${command} ${redactArgs(commandArgs).join(" ")} failed with exit code ${result.status ?? "unknown"}`);
  }
}

function writeJson(path, value) {
  mkdirSync(dirname(resolve(path)), { recursive: true });
  writeFileSync(resolve(path), `${JSON.stringify(value, null, 2)}\n`);
}

if (checkBytecode) {
  for (const contract of artifact.contracts) {
    const result = spawnSync("cast", ["code", contract.address, "--rpc-url", rpcUrl], {
      cwd: process.cwd(),
      encoding: "utf8",
    });
    if (result.status !== 0) {
      throw new Error(`cast code failed for ${contract.name}: ${result.stderr || result.stdout}`);
    }
    if (result.stdout.trim() === "0x") {
      throw new Error(`no bytecode found for ${contract.name} at ${contract.address}`);
    }
  }
}

const plan = {
  schema: "flowmemory.base_canary_source_verification_plan.v0",
  deploymentPath,
  reportPath,
  network: artifact.network,
  productionReady: false,
  submit,
  checkBytecode,
  continueOnError,
  delayMs,
  apiKeyEnv,
  contractCount: artifact.contracts.length,
  commands: artifact.contracts.map((contract) => ({
    name: contract.name,
    address: contract.address,
    sourceName: contract.sourceName,
    argv: ["forge", ...verificationArgs(contract, submit ? "<redacted>" : `<${apiKeyEnv}>`)],
  })),
};

writeJson(reportPath, plan);

if (json || !submit) {
  console.log(JSON.stringify(plan, null, 2));
}

if (submit) {
  const failures = [];
  for (const contract of artifact.contracts) {
    try {
      run("forge", verificationArgs(contract, apiKey));
    } catch (error) {
      failures.push({
        name: contract.name,
        address: contract.address,
        error: redact(error instanceof Error ? error.message : String(error)),
      });
      if (!continueOnError) {
        throw new Error(failures.at(-1).error);
      }
    }
    sleep(delayMs);
  }
  if (failures.length > 0) {
    const failure = new Error(`source verification completed with ${failures.length} failure(s)`);
    failure.failures = failures;
    console.error(JSON.stringify({ schema: "flowmemory.base_canary_source_verification_failures.v0", failures }, null, 2));
    process.exitCode = 1;
  }
}
