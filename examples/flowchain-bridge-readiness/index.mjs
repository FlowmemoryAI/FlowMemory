import {
  DEFAULT_FLOWCHAIN_RPC_URL,
  FlowChainBridgeNotReadyError,
  assertNoFlowChainSecrets,
  createFlowChainClient,
} from "../../packages/flowchain-sdk/src/index.ts";

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const client = createFlowChainClient({
  rpcUrl: arg("rpc-url", process.env.FLOWCHAIN_RPC_URL ?? DEFAULT_FLOWCHAIN_RPC_URL),
});

const readiness = await client.readiness();
const bridgeReadiness = await client.bridgeReadiness();
let ready = false;
let bridgeError = null;

try {
  await client.assertBridgeReady(bridgeReadiness);
  ready = true;
} catch (error) {
  if (error instanceof FlowChainBridgeNotReadyError) {
    bridgeError = {
      tag: error.tag,
      missingEnvNames: error.missingNames,
    };
  } else {
    throw error;
  }
}

const report = {
  schema: "flowchain.example.bridge_readiness.v0",
  status: ready ? "ready" : "blocked",
  publicRpcReady: readiness.publicRpcReady,
  bridgeFailClosedStatus: bridgeReadiness.failClosedStatus,
  readyForOperatorLivePilot: bridgeReadiness.readyForOperatorLivePilot,
  missingProductionEnvNames: readiness.missingProductionEnvNames,
  missingBridgeEnvNames: bridgeReadiness.missingEnvNames,
  bridgeError,
  envValuesPrinted: false,
  localOnly: true,
};

assertNoFlowChainSecrets(report);
console.log(JSON.stringify(report, null, 2));
