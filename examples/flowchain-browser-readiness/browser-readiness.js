const SECRET_PATTERN = /(privateKey|private_key|seed phrase|mnemonic|apiKey|webhook|bearer|auth token|access token|refresh token|password|passphrase|vault ciphertext)/i;

export function redactFlowChainBrowserText(value) {
  return String(value)
    .replace(/(https?:\/\/)([^/@\s]+@)/gi, "$1REDACTED@")
    .replace(/([?&](?:token|api_key|apikey|secret|key)=)[^&\s]+/gi, "$1REDACTED");
}

export function normalizeFlowChainOrigin(value) {
  const normalized = String(value ?? "").trim().replace(/\/+$/, "");
  if (!/^https?:\/\/[^/\s]+$/i.test(normalized)) {
    throw new Error("RPC origin must be an http(s) origin without a path.");
  }
  return normalized;
}

async function getJson(fetchImpl, origin, path) {
  const response = await fetchImpl(`${origin}${path}`, { headers: { accept: "application/json" } });
  const body = await response.json();
  return { status: response.status, body };
}

export async function checkFlowChainBrowserReadiness({ origin, fetchImpl = fetch }) {
  const rpcOrigin = normalizeFlowChainOrigin(origin);
  const discovery = await getJson(fetchImpl, rpcOrigin, "/rpc/discover");
  const readiness = await getJson(fetchImpl, rpcOrigin, "/rpc/readiness");
  const missingNames = Array.isArray(readiness.body?.missingProductionEnvNames)
    ? readiness.body.missingProductionEnvNames.map((name) => String(name)).filter((name) => /^FLOWCHAIN_[A-Z0-9_]+$/.test(name))
    : [];
  const publicRpcReady = readiness.body?.publicRpcReady === true;
  const productionReady = readiness.body?.productionReady === true;
  const publicReadyMethods = Number(readiness.body?.publicReadyMethodCount ?? discovery.body?.publicReadyMethodCount ?? 0);
  const methodCount = Number(discovery.body?.methodCount ?? 0);
  const summary = {
    schema: "flowchain.example.browser_readiness.v1",
    rpcOrigin: redactFlowChainBrowserText(rpcOrigin),
    discoveryStatus: discovery.status,
    readinessStatus: readiness.status,
    methodCount: Number.isFinite(methodCount) ? methodCount : 0,
    publicReadyMethodCount: Number.isFinite(publicReadyMethods) ? publicReadyMethods : 0,
    publicRpcReady,
    productionReady,
    safeToSharePublicly: publicRpcReady && productionReady && publicReadyMethods > 0,
    missingProductionEnvNames: missingNames,
    checkedEndpoints: ["/rpc/discover", "/rpc/readiness"],
    noSecrets: true,
  };
  const serialized = JSON.stringify(summary);
  if (SECRET_PATTERN.test(serialized)) {
    throw new Error("browser readiness summary contained secret-shaped text");
  }
  return summary;
}

export function renderFlowChainBrowserReadiness(root, summary) {
  const status = root.querySelector("[data-status]");
  const methods = root.querySelector("[data-methods]");
  const publicReady = root.querySelector("[data-public-ready]");
  const blockers = root.querySelector("[data-blockers]");
  const output = root.querySelector("[data-output]");
  status.textContent = summary.safeToSharePublicly ? "Shareable" : "Local only";
  status.dataset.state = summary.safeToSharePublicly ? "ready" : "blocked";
  methods.textContent = String(summary.methodCount);
  publicReady.textContent = String(summary.publicReadyMethodCount);
  blockers.textContent = summary.missingProductionEnvNames.length > 0 ? summary.missingProductionEnvNames.join(", ") : "none";
  output.textContent = JSON.stringify(summary, null, 2);
}
