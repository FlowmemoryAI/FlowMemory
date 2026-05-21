#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const failures = [];

function readText(path) {
  const resolved = resolve(root, path);
  if (!existsSync(resolved)) {
    failures.push(`missing required public file: ${path}`);
    return "";
  }
  return readFileSync(resolved, "utf8");
}

function assert(condition, message) {
  if (!condition) failures.push(message);
}

function includes(text, needle) {
  return text.includes(needle);
}

const packageJson = JSON.parse(readText("package.json"));
const scripts = packageJson.scripts ?? {};
const requiredScripts = [
  "public:hardening",
  "public:test:quick",
  "public:test:contracts",
  "public:test:e2e",
  "public:test:dashboard",
  "public:test:all",
  "public:test:report",
  "public:devkit",
  "public-agent-network:contracts",
  "public-agent-network:local-e2e",
];
for (const scriptName of requiredScripts) {
  assert(typeof scripts[scriptName] === "string" && scripts[scriptName].length > 0, `missing package script: ${scriptName}`);
}
assert(String(scripts["public:test:all"] ?? "").includes("public:hardening"), "public:test:all must include public:hardening");
assert(String(scripts["public:test:all"] ?? "").includes("check-unsafe-claims"), "public:test:all must run claim guardrails");

const requiredFiles = [
  "README.md",
  "docs/PUBLIC_REPO_GUIDE.md",
  "docs/PUBLIC_TESTER_GUIDE.md",
  "docs/PUBLIC_AGENT_NETWORK_RELEASE.md",
  "docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md",
  "docs/PUBLIC_RELEASE_GAPS.md",
  ".github/ISSUE_TEMPLATE/public-tester-report.yml",
  "infra/scripts/public-tester-report.mjs",
  "infra/scripts/check-unsafe-claims.mjs",
];
for (const path of requiredFiles) readText(path);

const readme = readText("README.md");
const publicGuide = readText("docs/PUBLIC_REPO_GUIDE.md");
const testerGuide = readText("docs/PUBLIC_TESTER_GUIDE.md");
const issueTemplate = readText(".github/ISSUE_TEMPLATE/public-tester-report.yml");
const ci = readText(".github/workflows/ci.yml");

const publicDocs = `${readme}\n${publicGuide}\n${testerGuide}`;
const bannedPublicEntrypoints = [
  "INSTALL_FLOWCHAIN_WINDOWS.ps1",
  "INSTALL_FLOWCHAIN",
  "winget install",
  "flowchain:prereq",
  "flowchain:init",
  "flowchain:start",
  "flowchain:full-smoke",
];
for (const phrase of bannedPublicEntrypoints) {
  assert(!includes(publicDocs, phrase), `public docs still expose confusing chain-devnet entrypoint: ${phrase}`);
}

const requiredReadmePhrases = [
  "accountability layer for autonomous agents",
  "Proof-of-Useful-Memory",
  "Agent Bonds",
  "task-scoped, capital-backed recourse records",
  "npm run public:test:quick",
  "docs/PUBLIC_TESTER_GUIDE.md",
];
for (const phrase of requiredReadmePhrases) {
  assert(includes(readme, phrase), `README missing public positioning phrase: ${phrase}`);
}

const requiredTesterPhrases = [
  "npm run public:test:quick",
  "npm run public:test:contracts",
  "npm run public:test:e2e",
  "npm run public:test:dashboard",
  "npm run public:test:all",
  "npm run public:test:report",
  "Public Tester Report",
  "Never include private keys",
];
for (const phrase of requiredTesterPhrases) {
  assert(includes(testerGuide, phrase), `PUBLIC_TESTER_GUIDE missing tester phrase: ${phrase}`);
}

const requiredIssueTemplatePhrases = [
  "public-tester",
  "tester-report",
  "I did not include private keys",
  "local/test public infrastructure",
];
for (const phrase of requiredIssueTemplatePhrases) {
  assert(includes(issueTemplate, phrase), `public tester issue template missing phrase: ${phrase}`);
}

const documentedScriptMatches = [...publicDocs.matchAll(/npm run ([A-Za-z0-9:_-]+)/g)].map((match) => match[1]);
for (const scriptName of documentedScriptMatches) {
  if (scriptName.startsWith("public") || scriptName.startsWith("public-agent-network")) {
    assert(typeof scripts[scriptName] === "string", `documented public script is missing from package.json: ${scriptName}`);
  }
}

assert(includes(ci, "Public repository readiness"), "CI missing Public repository readiness job");
assert(includes(ci, "npm run public:hardening"), "CI must run public:hardening");
assert(includes(ci, "npm run public:test:all"), "CI must run public:test:all");

if (failures.length > 0) {
  console.error("FlowMemory public repository hardening failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(JSON.stringify({
  service: "flowmemory-public-repo-hardening",
  ok: true,
  checkedScripts: requiredScripts.length,
  documentedPublicScripts: documentedScriptMatches.filter((name) => name.startsWith("public") || name.startsWith("public-agent-network")).length,
  checkedFiles: requiredFiles.length,
}, null, 2));
