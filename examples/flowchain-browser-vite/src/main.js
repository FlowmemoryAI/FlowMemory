import {
  DEFAULT_FLOWCHAIN_RPC_URL,
  createFlowChainClient,
  redactFlowChainSecrets,
} from "../../../packages/flowchain-sdk/src/index.ts";

const client = createFlowChainClient({
  rpcUrl: new URLSearchParams(window.location.search).get("rpc") ?? DEFAULT_FLOWCHAIN_RPC_URL,
});

function write(id, value) {
  document.getElementById(id).textContent = JSON.stringify(redactFlowChainSecrets(value), null, 2);
}

async function refresh() {
  const accountId = document.getElementById("account").value.trim();
  const [readiness, bridge, activity] = await Promise.all([
    client.readinessHttp(),
    client.bridgeReadiness(),
    client.transferHistory({ limit: 10 }),
  ]);
  write("readiness", {
    status: readiness.status,
    publicRpcReady: readiness.publicRpcReady,
    missingProductionEnvNames: readiness.missingProductionEnvNames,
    envValuesPrinted: readiness.envValuesPrinted,
  });
  write("bridge", {
    failClosedStatus: bridge.failClosedStatus,
    readyForOperatorLivePilot: bridge.readyForOperatorLivePilot,
    missingEnvNames: bridge.missingEnvNames,
    envValuesPrinted: bridge.envValuesPrinted,
  });
  try {
    write("balance", await client.balanceGet(accountId));
  } catch (error) {
    write("balance", { status: "unavailable", message: error.message });
  }
  write("activity", activity);
}

document.getElementById("refresh").addEventListener("click", () => {
  void refresh();
});

void refresh();
