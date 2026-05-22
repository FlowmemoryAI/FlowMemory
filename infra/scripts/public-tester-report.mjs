#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { arch, platform, release } from "node:os";
import { spawnSync } from "node:child_process";

const LANES = {
  quick: {
    label: "Quick JS smoke",
    command: ["npm", ["run", "public:test:quick"]],
  },
  contracts: {
    label: "Public-agent contracts",
    command: ["npm", ["run", "public:test:contracts"]],
  },
  e2e: {
    label: "Local public-agent e2e",
    command: ["npm", ["run", "public:test:e2e"]],
  },
  dashboard: {
    label: "Dashboard workbench",
    command: ["npm", ["run", "public:test:dashboard"]],
  },
  cli: {
    label: "CLI / control-plane trial",
    command: ["npm", ["run", "public:test:cli"]],
  },
};

const SECRET_PATTERNS = [
  [/sk-[A-Za-z0-9_-]{20,}/g, "sk-[REDACTED]"],
  [/gh[pousr]_[A-Za-z0-9_]{20,}/g, "gh[REDACTED]"],
  [/xox[baprs]-[A-Za-z0-9-]{20,}/g, "xox[REDACTED]"],
  [/AKIA[0-9A-Z]{16}/g, "AKIA[REDACTED]"],
  [/(PRIVATE_KEY\s*[:=]\s*)0x[0-9a-fA-F]{64}/gi, "$1[REDACTED]"],
  [/(MNEMONIC\s*[:=]\s*)[^\r\n]+/gi, "$1[REDACTED]"],
  [/(WEBHOOK_URL\s*[:=]\s*)[^\r\n]+/gi, "$1[REDACTED]"],
  [/(API_KEY\s*[:=]\s*)[^\r\n]+/gi, "$1[REDACTED]"],
];

function usage() {
  return `FlowMemory public tester report

Usage:
  node infra/scripts/public-tester-report.mjs [--quick] [--contracts] [--e2e] [--dashboard] [--cli] [--all] [--strict] [--out <path>]

Defaults to --quick. Writes a public-safe JSON report and markdown issue body under reports/local/public-test-reports/.
`;
}

function commandBin(name) {
  return name;
}

function shellQuote(value) {
  if (/^[A-Za-z0-9_./:=@-]+$/.test(value)) return value;
  return `"${value.replace(/"/g, "\\\"")}"`;
}

function shellCommand(bin, args) {
  return [bin, ...args].map(shellQuote).join(" ");
}

function redact(text) {
  let redacted = text;
  for (const [pattern, replacement] of SECRET_PATTERNS) {
    redacted = redacted.replace(pattern, replacement);
  }
  return redacted;
}

function excerpt(text, maxLines = 80) {
  const lines = redact(text).split(/\r?\n/).filter((line) => line.length > 0);
  if (lines.length <= maxLines) return lines.join("\n");
  const head = lines.slice(0, Math.floor(maxLines / 2));
  const tail = lines.slice(lines.length - Math.ceil(maxLines / 2));
  return [...head, `... ${lines.length - maxLines} lines omitted ...`, ...tail].join("\n");
}

function runCommand(bin, args, options = {}) {
  const started = Date.now();
  const useShell = process.platform === "win32";
  const result = spawnSync(
    useShell ? shellCommand(commandBin(bin), args) : commandBin(bin),
    useShell ? [] : args,
    {
      cwd: process.cwd(),
      env: { ...process.env, NO_COLOR: "1", FORCE_COLOR: "0" },
      encoding: "utf8",
      maxBuffer: 20 * 1024 * 1024,
      shell: useShell,
      ...options,
    },
  );
  const durationMs = Date.now() - started;
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  return {
    command: [bin, ...args].join(" "),
    exitCode: typeof result.status === "number" ? result.status : 1,
    signal: result.signal ?? null,
    error: result.error?.message ?? null,
    durationMs,
    outputExcerpt: excerpt(output),
  };
}

function tryVersion(bin, args = ["--version"]) {
  const result = runCommand(bin, args);
  if (result.exitCode !== 0) return null;
  return result.outputExcerpt.split(/\r?\n/)[0] ?? null;
}

function parseArgs(argv) {
  const lanes = new Set();
  let strict = false;
  let out = null;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--all") {
      Object.keys(LANES).forEach((lane) => lanes.add(lane));
    } else if (arg === "--quick") {
      lanes.add("quick");
    } else if (arg === "--contracts") {
      lanes.add("contracts");
    } else if (arg === "--e2e") {
      lanes.add("e2e");
    } else if (arg === "--dashboard") {
      lanes.add("dashboard");
    } else if (arg === "--cli") {
      lanes.add("cli");
    } else if (arg === "--strict") {
      strict = true;
    } else if (arg === "--out") {
      index += 1;
      out = argv[index] ?? null;
      if (out === null) throw new Error("--out requires a path");
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (lanes.size === 0) lanes.add("quick");
  return { lanes: [...lanes], strict, out };
}

function markdownIssueBody(report) {
  const results = report.results.map((result) => (
    `| ${result.laneLabel} | ${result.status} | ${result.exitCode} | ${result.durationMs}ms |`
  )).join("\n");
  const commands = report.results.map((result) => `- \`${result.command}\``).join("\n");
  const failures = report.results
    .filter((result) => result.status !== "passed")
    .map((result) => `### ${result.laneLabel}\n\n\`\`\`text\n${result.outputExcerpt}\n\`\`\``)
    .join("\n\n");

  return `## Public Tester Report

### Environment

- OS: ${report.environment.platform} ${report.environment.release} ${report.environment.arch}
- Node: ${report.environment.nodeVersion}
- npm: ${report.environment.npmVersion ?? "not found"}
- Forge: ${report.environment.forgeVersion ?? "not found"}
- Commit: ${report.repo.commit ?? "unknown"}

### Commands Run

${commands}

### Results

| Lane | Status | Exit | Duration |
| --- | --- | ---: | ---: |
${results}

${failures.length > 0 ? `### First Useful Failure Output\n\n${failures}\n\n` : ""}### Safety

- [x] I did not include private keys, seed phrases, RPC credentials, API keys, webhook URLs, wallet secrets, or private user data.
- [x] I understand this is local/test public infrastructure, not a production readiness claim.
`;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const timestamp = new Date().toISOString();
  const safeTimestamp = timestamp.replace(/[:.]/g, "-");
  const outputBase = resolve(args.out ?? `reports/local/public-test-reports/public-tester-report-${safeTimestamp}`);
  const selected = args.lanes.map((lane) => LANES[lane]);

  const repoCommit = runCommand("git", ["rev-parse", "HEAD"]);
  const repoBranch = runCommand("git", ["branch", "--show-current"]);
  const repoStatus = runCommand("git", ["status", "--short"]);

  const results = selected.map((lane) => {
    const [bin, laneArgs] = lane.command;
    const result = runCommand(bin, laneArgs);
    return {
      laneLabel: lane.label,
      command: result.command,
      status: result.exitCode === 0 ? "passed" : "failed",
      exitCode: result.exitCode,
      signal: result.signal,
      error: result.error,
      durationMs: result.durationMs,
      outputExcerpt: result.outputExcerpt,
    };
  });

  const report = {
    schema: "flowmemory.public_tester_report.v1",
    generatedAt: timestamp,
    localOnly: true,
    productionReady: false,
    repo: {
      branch: repoBranch.exitCode === 0 ? repoBranch.outputExcerpt.trim() : null,
      commit: repoCommit.exitCode === 0 ? repoCommit.outputExcerpt.trim() : null,
      dirty: repoStatus.exitCode === 0 ? repoStatus.outputExcerpt.trim().length > 0 : null,
      statusExcerpt: repoStatus.outputExcerpt,
    },
    environment: {
      platform: platform(),
      release: release(),
      arch: arch(),
      nodeVersion: process.version,
      npmVersion: tryVersion("npm", ["--version"]),
      forgeVersion: tryVersion("forge", ["--version"]),
    },
    selectedLanes: args.lanes,
    results,
  };
  report.issueBodyMarkdown = markdownIssueBody(report);

  mkdirSync(dirname(outputBase), { recursive: true });
  const jsonPath = `${outputBase}.json`;
  const markdownPath = `${outputBase}.md`;
  writeFileSync(jsonPath, `${JSON.stringify(report, null, 2)}\n`);
  writeFileSync(markdownPath, report.issueBodyMarkdown);

  const failed = results.filter((result) => result.status !== "passed");
  console.log(`FlowMemory public tester report: ${failed.length === 0 ? "passed" : "failed"}`);
  console.log(`JSON: ${jsonPath}`);
  console.log(`Markdown: ${markdownPath}`);
  for (const result of results) {
    console.log(`- ${result.laneLabel}: ${result.status} (${result.durationMs}ms)`);
  }

  if (args.strict && failed.length > 0) {
    process.exitCode = 1;
  }
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
