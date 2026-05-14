#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";

const repoRoot = process.cwd();
const reportDir = join(repoRoot, "devnet", "local", "live-rpc-wallet-dashboard");
const reportPath = join(reportDir, "no-secret-scan-report.json");
const npmCommand = "npm";
const nodeCommand = process.execPath;

const scannedSourceFiles = [
  "apps/dashboard/src/data/bridge.ts",
  "apps/dashboard/src/views/BridgeView.tsx",
  "services/control-plane/src/methods.ts",
  "services/control-plane/src/server.ts",
  "services/control-plane/src/transaction-envelope.ts",
].filter((file) => existsSync(join(repoRoot, file)));

const sourceSecretPatterns = [
  { label: "browser localStorage", pattern: /\blocalStorage\b/ },
  { label: "browser sessionStorage", pattern: /\bsessionStorage\b/ },
  { label: "private key marker", pattern: /\bprivate[_ -]?key\b/i },
  { label: "seed phrase marker", pattern: /\bseed[_ -]?phrase\b/i },
  { label: "mnemonic marker", pattern: /\bmnemonic\b/i },
  { label: "api key marker", pattern: /\bapi[_ -]?key\b/i },
  { label: "webhook url marker", pattern: /\bwebhook[_ -]?url\b/i },
  { label: "bearer token marker", pattern: /\bbearer[_ -]?token\b/i },
];

function run(command, args) {
  const file = process.platform === "win32" && command === "npm" ? "cmd.exe" : command;
  const finalArgs = process.platform === "win32" && command === "npm" ? ["/d", "/s", "/c", "npm", ...args] : args;
  const stdout = execFileSync(file, finalArgs, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  return stdout.trim();
}

function parseSmoke(stdout) {
  const start = stdout.indexOf("{");
  if (start < 0) {
    throw new Error("control-plane smoke did not print JSON");
  }
  return JSON.parse(stdout.slice(start));
}

function scanSourceFiles() {
  const findings = [];
  for (const file of scannedSourceFiles) {
    const text = readFileSync(join(repoRoot, file), "utf8");
    for (const { label, pattern } of sourceSecretPatterns) {
      if (pattern.test(text)) {
        findings.push({ file, label });
      }
    }
  }
  return findings;
}

mkdirSync(reportDir, { recursive: true });

const smokeStdout = run(npmCommand, ["run", "control-plane:smoke", "--silent"]);
const smoke = parseSmoke(smokeStdout);
if (smoke?.noSecretScan?.findingCount !== 0) {
  throw new Error(`control-plane smoke reported secret findings: ${JSON.stringify(smoke.noSecretScan)}`);
}

const unsafeClaimOutput = run(nodeCommand, ["infra/scripts/check-unsafe-claims.mjs"]);
const sourceFindings = scanSourceFiles();
const passed = sourceFindings.length === 0;
const report = {
  schema: "flowchain.live_rpc_wallet_dashboard.no_secret_scan_report.v1",
  generatedAt: new Date().toISOString(),
  passed,
  checks: {
    controlPlaneSmoke: {
      command: "npm run control-plane:smoke --silent",
      ok: smoke.ok === true,
      methodCount: smoke.methodCount,
      noSecretScan: smoke.noSecretScan,
    },
    unsafeClaimScan: {
      command: "node infra/scripts/check-unsafe-claims.mjs",
      ok: true,
      output: unsafeClaimOutput,
    },
    sourceScan: {
      files: scannedSourceFiles,
      findingCount: sourceFindings.length,
      findings: sourceFindings,
      excludesIgnoredWalletVaults: true,
    },
  },
  noBaseReleaseBroadcast: true,
  localOnly: true,
};

writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));

if (!passed) {
  process.exit(1);
}
