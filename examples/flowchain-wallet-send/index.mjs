import {
  DEFAULT_FLOWCHAIN_RPC_URL,
  assertNoFlowChainSecrets,
  createFlowChainClient,
  createLocalSignedEnvelope,
} from "../../packages/flowchain-sdk/src/index.ts";

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const fromAccountId = arg("from", "local-account:wallet-send:source");
const toAccountId = arg("to", "local-account:wallet-send:destination");
const amountUnits = Number(arg("amount", "1"));
const submittedBy = arg("submitted-by", "operator:flowchain-wallet-send-example");
const client = createFlowChainClient({
  rpcUrl: arg("rpc-url", process.env.FLOWCHAIN_RPC_URL ?? DEFAULT_FLOWCHAIN_RPC_URL),
});

if (!Number.isInteger(amountUnits) || amountUnits <= 0) {
  throw new Error("--amount must be a positive integer local test-unit amount");
}

const envelope = createLocalSignedEnvelope({
  type: "TransferLocalTestUnits",
  transferId: arg("transfer-id", `transfer:wallet-send:${Date.now()}`),
  fromAccountId,
  toAccountId,
  amountUnits,
  memo: "flowchain-wallet-send-example",
}, submittedBy);

const receipt = await client.submitSignedTransaction(envelope, {
  runtimeSubmit: true,
  submittedBy,
});

const report = {
  schema: "flowchain.example.wallet_send.v0",
  status: receipt.accepted ? "accepted" : "rejected",
  txId: receipt.txId,
  runtimeQueued: receipt.runtimeSubmission?.queued ?? [],
  forwardedTo: receipt.forwardedTo,
  localOnly: true,
};

assertNoFlowChainSecrets(report);
console.log(JSON.stringify(report, null, 2));
