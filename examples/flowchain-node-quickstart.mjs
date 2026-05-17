import { FlowChainClient, redactFlowChainText } from "../services/flowchain-sdk/src/index.ts";

function asRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function accountIdFromBalance(row) {
  return row.walletAddress ?? asRecord(row.balance).accountId ?? null;
}

function amountFromBalance(row) {
  const amount = row.amount ?? asRecord(row.balance).units ?? "0";
  return /^\d+$/.test(String(amount)) ? BigInt(String(amount)) : 0n;
}

async function main() {
  const rpcUrl = process.env.FLOWCHAIN_RPC_URL ?? "http://127.0.0.1:8787/rpc";
  const timeoutMs = Number.parseInt(process.env.FLOWCHAIN_RPC_TIMEOUT_MS ?? "30000", 10);
  const shouldSend = process.argv.includes("--send");
  const client = new FlowChainClient({
    rpcUrl,
    timeoutMs: Number.isFinite(timeoutMs) && timeoutMs > 0 ? timeoutMs : 30000,
  });

  const discovery = asRecord(await client.rpcDiscover());
  const readiness = asRecord(await client.rpcReadiness());
  const before = asRecord(await client.chainStatus());
  const blocks = asRecord(await client.blockList({ limit: 1 }));
  const transactions = asRecord(await client.transactionList({ limit: 1 }));
  const balances = asRecord(await client.walletBalances({ limit: 25 }));
  const balanceRows = asArray(balances.balances).map(asRecord);

  let walletSend = null;
  if (shouldSend) {
    const sender = balanceRows.find((row) => accountIdFromBalance(row) !== null && amountFromBalance(row) > 1n);
    const recipient = balanceRows.find((row) => accountIdFromBalance(row) !== null && accountIdFromBalance(row) !== accountIdFromBalance(sender ?? {}));
    if (sender === undefined || recipient === undefined) {
      throw new Error("example could not find two local no-value accounts for a wallet send");
    }
    walletSend = await client.walletSend({
      fromAccountId: accountIdFromBalance(sender),
      toAccountId: accountIdFromBalance(recipient),
      amountUnits: "1",
      memo: `flowchain-node-example-${Date.now()}`,
      applyBlock: true,
      createRecipient: true,
    });
  }

  const after = asRecord(await client.chainStatus());
  console.log(JSON.stringify({
    schema: "flowchain.example.node_quickstart.v0",
    status: "passed",
    rpcEndpoint: redactFlowChainText(rpcUrl),
    methodCount: discovery.methodCount ?? 0,
    publicRpcReady: readiness.publicRpcReady === true,
    beforeHeight: before.currentBlock ?? before.blockHeight ?? null,
    afterHeight: after.currentBlock ?? after.blockHeight ?? null,
    blockCount: blocks.count ?? 0,
    transactionCount: transactions.count ?? 0,
    balanceRows: balances.count ?? 0,
    walletSendSchema: asRecord(walletSend).schema ?? null,
    localOnly: readiness.localOnly !== false,
    noLiveBroadcast: true,
    noSecrets: true,
  }, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? redactFlowChainText(error.message) : redactFlowChainText(String(error)));
  process.exitCode = 1;
});
