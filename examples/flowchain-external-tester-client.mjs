#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const DEFAULT_CONNECT_PACK = "docs/agent-runs/live-product-infra-rpc/external-tester-connect-pack.json";
const REQUIRED_READ_ROUTES = ["/health", "/rpc/discover", "/rpc/readiness", "/chain/status", "/tester/status"];
const REQUIRED_WRITE_ROUTES = ["/tester/wallets/create", "/tester/faucet", "/tester/wallets/send"];

function parseArgs(argv) {
  const args = {
    connectPack: DEFAULT_CONNECT_PACK,
    baseUrl: "",
    tokenFile: "",
    dryRun: false,
    allowBlocked: false,
    walletLabel: "external-tester-client",
    sender: "",
    recipient: "",
    amountUnits: "1",
    memo: `external-tester-client-${Date.now()}`,
    output: "",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--dry-run") args.dryRun = true;
    else if (arg === "--allow-blocked") args.allowBlocked = true;
    else if (arg === "--connect-pack") args.connectPack = argv[++index] ?? args.connectPack;
    else if (arg === "--base-url") args.baseUrl = argv[++index] ?? "";
    else if (arg === "--token-file") args.tokenFile = argv[++index] ?? "";
    else if (arg === "--wallet-label") args.walletLabel = argv[++index] ?? args.walletLabel;
    else if (arg === "--sender") args.sender = argv[++index] ?? "";
    else if (arg === "--recipient") args.recipient = argv[++index] ?? "";
    else if (arg === "--amount-units") args.amountUnits = argv[++index] ?? args.amountUnits;
    else if (arg === "--memo") args.memo = argv[++index] ?? args.memo;
    else if (arg === "--output") args.output = argv[++index] ?? "";
    else throw new Error(`unknown argument: ${arg}`);
  }
  return args;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function endpoint(baseUrl, route) {
  return `${baseUrl.replace(/\/+$/, "")}${route}`;
}

function redactEndpoint(value) {
  return String(value)
    .replace(/^(https?:\/\/)([^/@]+@)/i, "$1[REDACTED]@")
    .replace(/([?&](?:token|api_key|apikey|key|secret)=)[^&#]+/gi, "$1[REDACTED]");
}

function safeTokenSummary(tokenFile) {
  if (!tokenFile) return { configured: false, source: "" };
  return { configured: true, source: basename(tokenFile) };
}

function assertNoSecretText(text, label) {
  const secretPattern = /(private[_ -]?key|seed[_ -]?phrase|mnemonic|bearer\s+[a-z0-9._~+/-]{12,}|token["']?\s*[:=]\s*["']?[a-z0-9._~+/-]{12,}|BEGIN (?:RSA |OPENSSH )?PRIVATE KEY)/i;
  if (secretPattern.test(text)) {
    throw new Error(`${label} contains a secret-shaped value`);
  }
}

async function requestJson({ url, method = "GET", token = "", body = undefined }) {
  const headers = { accept: "application/json" };
  if (body !== undefined) headers["content-type"] = "application/json";
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = null;
  try {
    json = text.length === 0 ? null : JSON.parse(text);
  } catch {
    json = { nonJsonBody: text.slice(0, 200) };
  }
  return {
    ok: response.ok,
    statusCode: response.status,
    schema: json && typeof json === "object" ? json.schema ?? null : null,
    body: json,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const connectPackPath = resolve(args.connectPack);
  if (!existsSync(connectPackPath)) {
    throw new Error(`connect pack does not exist: ${connectPackPath}`);
  }
  const connectPack = readJson(connectPackPath);
  const readRoutes = connectPack.endpoints?.readOnlyRoutes ?? [];
  const writeRoutes = connectPack.endpoints?.testerWriteRoutes ?? [];
  const missingReadRoutes = REQUIRED_READ_ROUTES.filter((route) => !readRoutes.includes(route));
  const missingWriteRoutes = REQUIRED_WRITE_ROUTES.filter((route) => !writeRoutes.includes(route));
  const baseUrl = args.baseUrl || connectPack.network?.baseUrlPlaceholder || "<OWNER_PUBLIC_ENDPOINT>";
  const shareable = connectPack.shareable === true;
  const blocked = !shareable && !args.allowBlocked;
  const plannedRoutes = [...REQUIRED_READ_ROUTES, ...REQUIRED_WRITE_ROUTES];
  const checks = {
    connectPackLoaded: connectPack.schema === "flowchain.external_tester_connect_pack.v0",
    shareableOrAllowedBlocked: shareable || args.allowBlocked,
    readRoutesCovered: missingReadRoutes.length === 0,
    writeRoutesCovered: missingWriteRoutes.length === 0,
    dryRunAvoidedNetwork: args.dryRun,
    noSecrets: true,
  };

  let status = blocked ? "blocked" : "planned";
  const networkResults = {};
  if (!args.dryRun && !blocked) {
    if (!args.baseUrl || args.baseUrl.includes("<")) {
      throw new Error("--base-url is required for non-dry-run execution");
    }
    if (!args.tokenFile || !existsSync(args.tokenFile)) {
      throw new Error("--token-file is required for tester write execution");
    }
    const token = readFileSync(args.tokenFile, "utf8").trim();
    if (token.length < 12) throw new Error("tester token file is empty or too short");

    for (const route of REQUIRED_READ_ROUTES) {
      networkResults[route] = await requestJson({ url: endpoint(args.baseUrl, route) });
    }
    networkResults["/tester/wallets/create"] = await requestJson({
      url: endpoint(args.baseUrl, "/tester/wallets/create"),
      method: "POST",
      token,
      body: { label: args.walletLabel },
    });
    if (args.sender) {
      networkResults["/tester/faucet"] = await requestJson({
        url: endpoint(args.baseUrl, "/tester/faucet"),
        method: "POST",
        token,
        body: { accountId: args.sender, amountUnits: args.amountUnits, reason: "external-tester-client" },
      });
    }
    if (args.sender && args.recipient) {
      networkResults["/tester/wallets/send"] = await requestJson({
        url: endpoint(args.baseUrl, "/tester/wallets/send"),
        method: "POST",
        token,
        body: {
          from: args.sender,
          to: args.recipient,
          amountUnits: args.amountUnits,
          memo: args.memo,
          createRecipient: false,
        },
      });
    }
    status = Object.values(networkResults).every((result) => result.ok) ? "passed" : "failed";
  }

  const report = {
    schema: "flowchain.external_tester_client_report.v0",
    generatedAt: new Date().toISOString(),
    status,
    dryRun: args.dryRun,
    shareable,
    blockedReason: blocked ? "connect-pack-not-shareable" : null,
    connectPackPath,
    endpoint: redactEndpoint(baseUrl),
    token: safeTokenSummary(args.tokenFile),
    plannedRoutes,
    missingReadRoutes,
    missingWriteRoutes,
    networkResults: redactNetworkResults(networkResults),
    checks,
    broadcasts: false,
    envValuesPrinted: false,
    noSecrets: true,
  };
  const text = JSON.stringify(report, null, 2);
  assertNoSecretText(text, "external tester client report");
  if (args.output) {
    writeFileSync(resolve(args.output), `${text}\n`, "utf8");
  }
  console.log(text);
  if (status === "failed" || (status === "blocked" && !args.allowBlocked)) process.exitCode = 1;
}

function redactNetworkResults(results) {
  return Object.fromEntries(Object.entries(results).map(([route, result]) => {
    const safe = { ...result };
    delete safe.body;
    return [route, safe];
  }));
}

main().catch((error) => {
  console.error(JSON.stringify({
    schema: "flowchain.external_tester_client_error.v0",
    status: "failed",
    message: error instanceof Error ? error.message : String(error),
    noSecrets: true,
  }, null, 2));
  process.exitCode = 1;
});
