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
const dashboardPackageJson = JSON.parse(readText("apps/dashboard/package.json"));
const dashboardScripts = dashboardPackageJson.scripts ?? {};
const requiredScripts = [
  "public:hardening",
  "public:test:quick",
  "public:test:contracts",
  "public:test:e2e",
  "public:test:dashboard",
  "public:test:all",
  "public:test:report",
  "public:test:cli",
  "public-agent-network:contracts",
  "public-agent-network:local-e2e",
];
for (const scriptName of requiredScripts) {
  assert(typeof scripts[scriptName] === "string" && scripts[scriptName].length > 0, `missing package script: ${scriptName}`);
}
assert(scripts["public:" + "devkit"] === undefined, "public package scripts must not expose the older internal devkit alias");
assert(String(scripts["public:test:all"] ?? "").includes("public:hardening"), "public:test:all must include public:hardening");
assert(String(scripts["public:test:all"] ?? "").includes("public:test:cli"), "public:test:all must include CLI smoke");
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
  "docs/MOBILE_APPS.md",
  "apps/dashboard/WALLET_DISTRIBUTION.md",
  "apps/dashboard/package.json",
  "apps/dashboard/capacitor.config.ts",
  "apps/dashboard/electron-builder.json",
  "apps/dashboard/index.html",
  "apps/dashboard/android/app/build.gradle",
  "apps/dashboard/android/app/src/main/res/values/strings.xml",
  ".github/workflows/ci.yml",
  ".github/workflows/wallet-release.yml",
  ".gitignore",
];
for (const path of requiredFiles) readText(path);
const legacyBrand = ["FLOW", "CHAIN"].join("");
const legacyScriptPrefix = ["flow", "chain"].join("");
const legacyLocalWord = ["dev", "net"].join("");
const forbiddenPublicFiles = [
  "INSTALL_" + legacyBrand + "_WINDOWS.ps1",
  "START_" + legacyBrand + "_LOCAL.ps1",
  "docs/" + legacyBrand + "_FULL_PRIVATE_TESTNET.md",
  "docs/" + legacyBrand + "_SECOND_COMPUTER_SETUP.md",
  "docs/" + legacyBrand + "_TESTNET_ACCEPTANCE.md",
  "docs/L" + "1_RESEARCH_INVENTORY.md",
];
for (const path of forbiddenPublicFiles) {
  assert(!existsSync(resolve(root, path)), `non-public launch artifact must not remain in the public repo: ${path}`);
}


const readme = readText("README.md");
const publicGuide = readText("docs/PUBLIC_REPO_GUIDE.md");
const testerGuide = readText("docs/PUBLIC_TESTER_GUIDE.md");
const publicRelease = readText("docs/PUBLIC_AGENT_NETWORK_RELEASE.md");
const publicTechnicalGuide = readText("docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md");
const issueTemplate = readText(".github/ISSUE_TEMPLATE/public-tester-report.yml");
const ci = readText(".github/workflows/ci.yml");
const releaseWorkflow = readText(".github/workflows/wallet-release.yml");
const mobileDocs = readText("docs/MOBILE_APPS.md");
const walletDistribution = readText("apps/dashboard/WALLET_DISTRIBUTION.md");
const capacitorConfig = readText("apps/dashboard/capacitor.config.ts");
const electronBuilder = readText("apps/dashboard/electron-builder.json");
const dashboardHtml = readText("apps/dashboard/index.html");
const androidGradle = readText("apps/dashboard/android/app/build.gradle");
const androidStrings = readText("apps/dashboard/android/app/src/main/res/values/strings.xml");
const publicGaps = readText("docs/PUBLIC_RELEASE_GAPS.md");
const reportScript = readText("infra/scripts/public-tester-report.mjs");
const gitignore = readText(".gitignore");

const publicDocs = `${readme}\n${publicGuide}\n${testerGuide}`;
const publicSurfaceDocs = [
  ["README.md", readme],
  ["docs/PUBLIC_REPO_GUIDE.md", publicGuide],
  ["docs/PUBLIC_TESTER_GUIDE.md", testerGuide],
  ["docs/PUBLIC_AGENT_NETWORK_RELEASE.md", publicRelease],
  ["docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md", publicTechnicalGuide],
  ["docs/PUBLIC_RELEASE_GAPS.md", publicGaps],
  ["docs/MOBILE_APPS.md", mobileDocs],
  ["apps/dashboard/WALLET_DISTRIBUTION.md", walletDistribution],
];
const bannedPublicEntrypoints = [
  `INSTALL_${legacyBrand}_WINDOWS.ps1`,
  `INSTALL_${legacyBrand}`,
  "winget install",
  `${legacyScriptPrefix}:prereq`,
  `${legacyScriptPrefix}:init`,
  `${legacyScriptPrefix}:start`,
  `${legacyScriptPrefix}:full-smoke`,
  "public:" + "devkit",
  `${legacyLocalWord}/local`,
  `chain-${legacyLocalWord}`,
];
for (const phrase of bannedPublicEntrypoints) {
  assert(!includes(publicDocs, phrase), `public docs still expose confusing non-public entrypoint: ${phrase}`);
}

const withheldPublicTerms = [
  ["Flow", "Chain"].join(""),
  ["Flow", " Chain"].join(""),
  ["flow", "chain"].join(""),
  ["app", "chain"].join(""),
  ["dev", "net"].join(""),
  "L" + "1",
];
for (const [path, text] of publicSurfaceDocs) {
  for (const phrase of withheldPublicTerms) {
    assert(!includes(text, phrase), `${path} must not surface non-public infrastructure term: ${phrase}`);
  }
}

const requiredReadmePhrases = [
  "actions/workflows/ci.yml/badge.svg",
  "actions/workflows/wallet-release.yml/badge.svg",
  "Public Guide](docs/PUBLIC_REPO_GUIDE.md)",
  "accountability layer for autonomous agents",
  "Proof-of-Useful-Memory",
  "Agent Bonds",
  "task-scoped, capital-backed recourse records",
  "npm run public:test:quick",
  "npm run public:test:cli",
  "docs/PUBLIC_TESTER_GUIDE.md",
  "iOS and Android app track",
  "docs/MOBILE_APPS.md",
];
for (const phrase of requiredReadmePhrases) {
  assert(includes(readme, phrase), `README missing public positioning phrase: ${phrase}`);
}

const requiredTesterPhrases = [
  "npm run public:test:quick",
  "npm run public:test:contracts",
  "npm run public:test:e2e",
  "npm run public:test:dashboard",
  "npm run public:test:cli",
  "npm run public:test:all",
  "npm run public:test:report",
  "reports/local/public-test-reports",
  "Public Tester Report",
  "Never include private keys",
];
for (const phrase of requiredTesterPhrases) {
  assert(includes(testerGuide, phrase), `PUBLIC_TESTER_GUIDE missing tester phrase: ${phrase}`);
}
assert(includes(reportScript, "reports/local/public-test-reports"), "public tester report script must write under reports/local");
assert(includes(gitignore, "reports/local/"), ".gitignore must ignore local public tester reports");

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
assert(!includes(ci, `name: Local ${legacyLocalWord}`), "public CI must not expose the older local runtime job");
assert(!includes(ci, `crates/flowmemory-${legacyLocalWord}/Cargo.toml`), "public CI must not expose the older local runtime crate path");
assert(includes(publicGuide, "#174"), "PUBLIC_REPO_GUIDE must mention the mobile gap issue");

const requiredMobilePhrases = [
  "FlowMemory's mobile apps are the user-facing control surface",
  "Android Capacitor shell exists",
  "iOS is part of the product direction but no Xcode project is committed yet",
  "task inbox for objective Agent Bonds work",
  "recourse quote and failure-waterfall viewer",
];
for (const phrase of requiredMobilePhrases) {
  assert(includes(mobileDocs, phrase), `MOBILE_APPS missing mobile positioning phrase: ${phrase}`);
}
assert(includes(walletDistribution, "FlowMemory operator app"), "WALLET_DISTRIBUTION must describe FlowMemory operator app");
assert(includes(releaseWorkflow, "name: FlowMemory app release"), "release workflow must use FlowMemory app release branding");
assert(includes(releaseWorkflow, "flowmemory-desktop"), "release workflow must name desktop artifacts FlowMemory");
assert(includes(releaseWorkflow, "flowmemory-android"), "release workflow must name Android artifacts FlowMemory");
assert(includes(releaseWorkflow, "FLOWMEMORY_ANDROID_KEYSTORE_BASE64"), "release workflow must use FlowMemory Android signing secret names");
assert(!includes(releaseWorkflow, `${legacyBrand}_ANDROID`), "release workflow must not expose older Android signing secret names");
assert(includes(electronBuilder, '"productName": "FlowMemory"'), "Electron product name must be FlowMemory");
assert(includes(dashboardHtml, "<title>FlowMemory</title>"), "dashboard HTML title must be FlowMemory");
assert(includes(capacitorConfig, "appName: \"FlowMemory\""), "Capacitor app name must be FlowMemory");
assert(includes(androidStrings, "<string name=\"app_name\">FlowMemory</string>"), "Android display app name must be FlowMemory");
assert(includes(androidGradle, 'applicationId "ai.flowmemory.operator"'), "Android applicationId must use FlowMemory operator package");
for (const scriptName of ["mobile:sync", "mobile:android:sync", "mobile:android:debug"]) {
  assert(typeof dashboardScripts[scriptName] === "string" && dashboardScripts[scriptName].length > 0, `missing dashboard mobile script: ${scriptName}`);
}
assert(includes(publicGaps, "Mobile operator apps and iOS shell"), "PUBLIC_RELEASE_GAPS must track mobile operator app hardening");
assert(includes(publicGaps, "https://github.com/FlowmemoryAI/FlowMemory/issues/174"), "PUBLIC_RELEASE_GAPS must link the mobile operator app tracking issue");

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
