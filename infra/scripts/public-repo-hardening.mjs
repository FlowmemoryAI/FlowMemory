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
  "public-agent-network:base-sepolia",
  "public-agent-network:base-sepolia:plan",
  "public-agent-network:base-sepolia:broadcast",
  "public-agent-network:base-sepolia:readback",
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
  "docs/WORKTREE_ASSIGNMENTS.md",
  "infra/scripts/public-tester-report.mjs",
  "infra/scripts/check-unsafe-claims.mjs",
  "infra/scripts/run-public-agent-network-base-sepolia-deploy.mjs",
  "infra/scripts/public-agent-network-base-sepolia-readback.mjs",
  "script/DeployPublicAgentNetworkBaseSepolia.s.sol",
  "fixtures/deployments/public-agent-network-base-sepolia-plan.json",
  "docs/DEPLOYMENTS/BASE_SEPOLIA_PUBLIC_AGENT_NETWORK.md",
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
  "docs/" + ["AGENT", "_", "PROMPTS.md"].join(""),
  "docs/" + ["agent", "-runs", "/README.md"].join(""),
  "docs/" + ["agent", "-goals", "/README.md"].join(""),
  "inbox/" + ["clau", "de-code", "/.gitkeep"].join(""),
  "inbox/" + ["old", "-prompts", "/.gitkeep"].join(""),
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
const publicAgentBaseSepoliaDeployScript = readText("infra/scripts/run-public-agent-network-base-sepolia-deploy.mjs");
const publicAgentBaseSepoliaReadbackScript = readText("infra/scripts/public-agent-network-base-sepolia-readback.mjs");
const publicAgentBaseSepoliaPlan = readText("fixtures/deployments/public-agent-network-base-sepolia-plan.json");
const publicAgentBaseSepoliaRunbook = readText("docs/DEPLOYMENTS/BASE_SEPOLIA_PUBLIC_AGENT_NETWORK.md");
const gitignore = readText(".gitignore");
const contributorInstructions = readText("AGENTS.md");
const startHere = readText("docs/START_HERE.md");
const dailyRunbook = readText("docs/DAILY_HQ_RUNBOOK.md");
const worktreeAssignments = readText("docs/WORKTREE_ASSIGNMENTS.md");
const launchCoreGoals = readText("docs/LAUNCH_CORE_AGENT_GOALS.md");
const setupWorktreesScript = readText("infra/scripts/setup-worktrees.ps1");
const sendGoalScript = readText("infra/scripts/send-goal-to-agent.ps1");

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
const publicProfessionalSurfaceDocs = [
  ...publicSurfaceDocs,
  ["AGENTS.md", contributorInstructions],
  ["docs/START_HERE.md", startHere],
  ["docs/DAILY_HQ_RUNBOOK.md", dailyRunbook],
  ["docs/WORKTREE_ASSIGNMENTS.md", worktreeAssignments],
  ["docs/LAUNCH_CORE_AGENT_GOALS.md", launchCoreGoals],
  [".github/workflows/ci.yml", ci],
  [".gitignore", gitignore],
  ["infra/scripts/setup-worktrees.ps1", setupWorktreesScript],
  ["infra/scripts/send-goal-to-agent.ps1", sendGoalScript],
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

const toolOriginTerms = [
  ["Co", "dex"].join(""),
  ["co", "dex"].join(""),
  ["Clau", "de"].join(""),
  ["clau", "de"].join(""),
  ["vi", "be"].join(""),
  ["AGENT", "_", "PROMPTS"].join(""),
  ["agent", "-runs"].join(""),
  ["agent", "-goals"].join(""),
  ["old", "-prompts"].join(""),
  ["clau", "de-code"].join(""),
  ["raw", " prompt"].join(""),
  ["prompt", " pack"].join(""),
];
for (const [path, text] of publicProfessionalSurfaceDocs) {
  for (const phrase of toolOriginTerms) {
    assert(!includes(text, phrase), `${path} must not expose internal tool-origin language: ${phrase}`);
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
assert(includes(publicGaps, "public-agent deployment, smoke-broadcast, source-verification, and bounded event-readback tooling now exists"), "PUBLIC_RELEASE_GAPS must record Base Sepolia public-agent tooling state");
assert(includes(publicAgentBaseSepoliaPlan, "0x69F55917209C446bf9d31D2903e01966B75a8cDe"), "Base Sepolia public-agent plan must include the configured public deployer address");
assert(includes(publicAgentBaseSepoliaPlan, "public_agent_network.base_sepolia_plan.v1"), "Base Sepolia public-agent plan must use the expected schema");
assert(includes(publicAgentBaseSepoliaDeployScript, "BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS"), "Base Sepolia deploy script must check the declared deployer address");
assert(includes(publicAgentBaseSepoliaDeployScript, "<set:redacted>"), "Base Sepolia deploy script must redact secret env presence");
assert(includes(publicAgentBaseSepoliaReadbackScript, "missingRequiredGroups"), "Base Sepolia readback script must enforce required event groups");
assert(includes(publicAgentBaseSepoliaReadbackScript, "Base Sepolia readback only"), "Base Sepolia readback script must write testnet boundaries");
assert(includes(publicAgentBaseSepoliaRunbook, "0x69F55917209C446bf9d31D2903e01966B75a8cDe"), "Base Sepolia runbook must include the configured public deployer address");
assert(includes(publicAgentBaseSepoliaRunbook, "Never include private keys"), "Base Sepolia runbook must include secret-handling guidance");

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
