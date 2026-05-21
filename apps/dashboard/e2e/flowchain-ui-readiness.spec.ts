import { expect, test, type Page, type Route } from "@playwright/test";

const TESTER_TOKEN = "local-tester-write-token";
const TESTER_ACCOUNT_A = "local-account:tester-browser-a";
const TESTER_ACCOUNT_B = "local-account:tester-browser-b";

type BrowserState = {
  created: boolean;
  funded: boolean;
  sent: boolean;
  unhandledRequests: string[];
};

async function fulfillJson(route: Route, payload: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    body: JSON.stringify(payload),
  });
}

async function installControlPlaneMocks(page: Page, state: BrowserState) {
  await page.route("https://api.coinbase.com/**", async (route) => {
    await fulfillJson(route, { data: { rates: { USD: "3241.17" } } });
  });

  await page.route("http://127.0.0.1:8787/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const pathname = url.pathname;
    const method = request.method();

    if (pathname === "/health") {
      await fulfillJson(route, {
        status: "ok",
        endpoints: [
          "GET /health",
          "GET /state",
          "GET /wallets/operator",
          "GET /wallets/balances",
          "GET /wallets/transfers",
          "GET /tester/status",
          "POST /tester/wallets/create",
          "POST /tester/faucet",
          "POST /tester/wallets/send",
        ],
      });
      return;
    }

    if (pathname === "/rpc" && method === "POST") {
      const payload = request.postDataJSON() as Array<{ id?: string | number }> | { id?: string | number };
      const requests = Array.isArray(payload) ? payload : [payload];
      await fulfillJson(route, requests.map((entry) => ({
        jsonrpc: "2.0",
        id: entry.id ?? null,
        result: null,
      })));
      return;
    }

    if (pathname === "/state") {
      await fulfillJson(route, {
        state: {
          chainId: "flowmemory-local-devnet-v0",
          nextBlockNumber: 63002,
          blocks: state.sent
            ? [{
                blockNumber: 63001,
                blockHash: `0x${"6".repeat(64)}`,
                parentHash: `0x${"5".repeat(64)}`,
                stateRoot: `0x${"7".repeat(64)}`,
                txIds: ["tx:tester-browser-a-b"],
                receipts: [{ txId: "tx:tester-browser-a-b", status: "applied" }],
              }]
            : [],
          faucetRecords: state.funded
            ? [{
                eventId: "faucet:tester-browser-a",
                accountId: TESTER_ACCOUNT_A,
                amountUnits: "2",
                status: "observed",
                blockNumber: 63000,
              }]
            : [],
          walletMetadata: state.created
            ? [{
                walletId: TESTER_ACCOUNT_A,
                operatorId: TESTER_ACCOUNT_A,
                status: "verified",
                secretMaterialBoundary: "Public metadata only.",
              }]
            : [],
        },
      });
      return;
    }

    if (pathname === "/pilot/status") {
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.real_value_pilot_status.v0",
        state: "degraded",
        label: "FlowChain capped owner real-value pilot",
        cappedOwnerTesting: true,
        broadPublicReadiness: false,
        productionReady: false,
        browserStoresSecrets: false,
        nextOperatorStep: {
          command: "npm run flowchain:public-deployment:contract -- -AllowBlocked",
        },
        lifecycle: [],
      });
      return;
    }

    if (pathname === "/bridge/live-readiness") {
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.bridge_live_readiness.v0",
        baseChainId: 8453,
        failClosedStatus: "BLOCKED",
        readyForOperatorLivePilot: false,
        missingEnvNames: ["FLOWCHAIN_BASE8453_RPC_URL"],
        envValuesPrinted: false,
        noSecrets: true,
        productionReady: false,
      });
      return;
    }

    if (pathname === "/pilot/lifecycle") {
      await fulfillJson(route, { schema: "flowmemory.control_plane.bridge_lifecycle_record_list.v0", count: 0, lifecycleRecords: [] });
      return;
    }

    if (pathname === "/wallets/operator") {
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.local_wallet_status.v0",
        exists: state.created,
        account: state.created ? { accountId: TESTER_ACCOUNT_A, address: TESTER_ACCOUNT_A, keyScheme: "secp256k1", status: "ready" } : null,
        secretMaterialReturned: false,
        noSecrets: true,
      });
      return;
    }

    if (pathname === "/wallets/balances") {
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.wallet_balance_list.v0",
        count: state.funded ? 1 : 0,
        balances: state.funded
          ? [{ balanceId: "balance:tester-browser-a", walletAddress: TESTER_ACCOUNT_A, asset: "local-test-unit", amount: "2", status: "credited", source: "tester-faucet" }]
          : [],
      });
      return;
    }

    if (pathname === "/wallets/transfers") {
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.wallet_transfer_history.v0",
        count: state.sent ? 1 : 0,
        transfers: state.sent
          ? [{ transferId: "transfer:tester-browser-a-b", txId: "tx:tester-browser-a-b", fromAccountId: TESTER_ACCOUNT_A, toAccountId: TESTER_ACCOUNT_B, assetId: "local-test-unit", amount: "1", status: "applied" }]
          : [],
      });
      return;
    }

    if (pathname === "/pilot/credits") {
      await fulfillJson(route, { schema: "flowmemory.control_plane.pilot_credit_list.v0", credits: [] });
      return;
    }

    if (pathname === "/bridge/status") {
      await fulfillJson(route, {
        deposits: 0,
        credits: state.funded ? 1 : 0,
        applied: state.sent ? 1 : 0,
        publicProductionL1Ready: false,
        liveRuntimeHandoffLoaded: true,
      });
      return;
    }

    if (pathname === "/tester/status") {
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.tester_write_status.v0",
        configured: true,
        enabled: true,
        tokenHashConfigured: true,
        maxSendUnits: "2",
        missingEnvNames: [],
        invalidEnvNames: [],
        envValuesPrinted: false,
        noSecrets: true,
        localOnly: true,
      });
      return;
    }

    if (pathname === "/tester/wallets/create" && method === "POST") {
      expect(request.headers().authorization).toBe(`Bearer ${TESTER_TOKEN}`);
      state.created = true;
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.tester_wallet_create_result.v0",
        created: true,
        secretMaterialReturned: false,
        credentialStored: false,
        noSecrets: true,
        account: { accountId: TESTER_ACCOUNT_A, address: TESTER_ACCOUNT_A, keyScheme: "secp256k1", status: "ready" },
      });
      return;
    }

    if (pathname === "/tester/faucet" && method === "POST") {
      expect(request.headers().authorization).toBe(`Bearer ${TESTER_TOKEN}`);
      state.funded = true;
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.tester_faucet_result.v0",
        accepted: true,
        applied: true,
        status: "applied",
        txIds: ["tx:tester-faucet-browser-a"],
        accountId: TESTER_ACCOUNT_A,
        assetId: "local-test-unit",
        amountUnits: "2",
        balancesAfter: { account: "2" },
      });
      return;
    }

    if (pathname === "/tester/wallets/send" && method === "POST") {
      expect(request.headers().authorization).toBe(`Bearer ${TESTER_TOKEN}`);
      state.sent = true;
      await fulfillJson(route, {
        schema: "flowmemory.control_plane.tester_wallet_send_result.v0",
        accepted: true,
        applied: true,
        transferId: "transfer:tester-browser-a-b",
        txIds: ["tx:tester-browser-a-b"],
        assetId: "local-test-unit",
        amountUnits: "1",
        status: "applied",
        from: { requestedAccountId: TESTER_ACCOUNT_A, runtimeAccountId: TESTER_ACCOUNT_A, resolution: "matched" },
        to: { requestedAccountId: TESTER_ACCOUNT_B, runtimeAccountId: TESTER_ACCOUNT_B, resolution: "matched" },
      });
      return;
    }

    state.unhandledRequests.push(`${method} ${pathname}`);
    await fulfillJson(route, { schema: "flowmemory.control_plane.unhandled_mock.v0", noSecrets: true });
  });
}

async function expectNoUiLeakage(page: Page) {
  const bodyText = await page.locator("body").innerText();
  expect(bodyText).not.toContain(TESTER_TOKEN);
  expect(bodyText).not.toContain("privateKey");
  expect(bodyText).not.toContain("seed phrase");
  expect(bodyText).not.toContain("mnemonic");

  const storage = await page.evaluate(() => ({
    localStorage: { ...window.localStorage },
    sessionStorage: { ...window.sessionStorage },
  }));
  expect(JSON.stringify(storage)).not.toContain(TESTER_TOKEN);
  expect(JSON.stringify(storage)).not.toContain("privateKey");
}

async function expectNoHorizontalOverflow(page: Page) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(2);
}

test.describe("FlowChain wallet, faucet, and explorer browser readiness", () => {
  test("completes the tester wallet funding loop and keeps the explorer inspectable", async ({ page }) => {
    const consoleErrors: string[] = [];
    const state: BrowserState = { created: false, funded: false, sent: false, unhandledRequests: [] };

    page.on("console", (message) => {
      if (message.type() === "error") {
        consoleErrors.push(message.text());
      }
    });
    page.on("pageerror", (error) => {
      consoleErrors.push(error.message);
    });

    await installControlPlaneMocks(page, state);
    await page.goto("/wallet?panel=tester");

    await expect(page.getByText("Tester gateway configured")).toBeVisible();
    await expect(page.getByLabel("Tester launch path")).toContainText("Create, fund, send, inspect");
    await expect(page.getByLabel("Tester launch path")).toContainText("needs passphrase");
    await page.getByLabel("Tester bearer token").fill(TESTER_TOKEN);
    await page.getByLabel("Tester wallet label").fill("friend-browser-a");
    await page.getByLabel("Tester wallet passphrase").fill("browser-test-passphrase");
    await page.getByRole("button", { name: /Create tester wallet/ }).click();
    await expect(page.getByRole("status")).toContainText("Tester wallet created");
    await expect(page.getByLabel("Tester launch path")).toContainText("wallet ready");
    await expect(page.getByLabel("Fund account")).toHaveValue(TESTER_ACCOUNT_A);

    await page.getByRole("button", { name: "Tester", exact: true }).click();
    await page.getByLabel("Fund account").fill(TESTER_ACCOUNT_A);
    await page.getByLabel("Faucet units").fill("3");
    await expect(page.getByLabel("Faucet units")).toHaveAttribute("aria-invalid", "true");
    await expect(page.getByRole("button", { name: /Request tester faucet/ })).toBeDisabled();
    await page.getByLabel("Faucet units").fill("2");
    await page.getByRole("button", { name: /Request tester faucet/ }).click();
    await expect(page.getByRole("status")).toContainText("Tester faucet accepted");
    await expect(page.getByLabel("Tester launch path")).toContainText("funding proof");
    await expect(page.getByLabel("Sender account")).toHaveValue(TESTER_ACCOUNT_A);

    await page.getByRole("button", { name: "Tester", exact: true }).click();
    await page.getByLabel("Sender account").fill(TESTER_ACCOUNT_A);
    await page.getByLabel("Recipient account").fill(TESTER_ACCOUNT_B);
    await page.getByLabel("Amount units").fill("3");
    await expect(page.getByLabel("Amount units")).toHaveAttribute("aria-invalid", "true");
    await expect(page.getByRole("button", { name: /Send tester units/ })).toBeDisabled();
    await page.getByLabel("Amount units").fill("1");
    await page.getByRole("button", { name: /Send tester units/ }).click();
    await expect(page.getByRole("status")).toContainText("Tester send accepted");
    await expect(page.getByText("Tester send applied")).toBeVisible();

    await page.getByRole("button", { name: "Tester", exact: true }).click();
    await page.getByRole("link", { name: /Inspect tester activity/ }).click();
    await expect(page).toHaveURL(/\/explorer$/);
    await page.reload();
    await expect(page.getByRole("heading", { name: "Flowchain explorer" })).toBeVisible();
    await expect(page.getByLabel("Tester settlement trace").getByText("Create, fund, send, inspect")).toBeVisible();
    await expect(page.getByText("Funding proofs", { exact: true })).toBeVisible();
    await expect(page.getByText("Wallet records", { exact: true })).toBeVisible();

    await page.getByRole("button", { name: /Faucet/ }).first().click();
    await expect(page.getByLabel("Explorer records")).toContainText(/faucet/i);

    await page.getByRole("button", { name: /Transactions/ }).first().click();
    await expect(page.getByLabel("Explorer records")).toContainText(/transaction|transfer/i);

    await page.goto("/tester");
    await expect(page.getByRole("heading", { name: "Friends-and-family launch" })).toBeVisible();
    await expect(page.getByLabel("Tester launch status")).toContainText("Live infra");
    await expect(page.getByLabel("Tester launch status")).toContainText("Missing inputs");
    await expect(page.getByLabel("Tester launch status")).toContainText("RPC command matrix");
    await expect(page.getByText("RPC headers", { exact: true }).first()).toBeVisible();
    await expect(page.getByText("HSTS, no-sniff, no-store, CSP")).toBeVisible();
    await expect(page.getByText("RPC matrix", { exact: true }).first()).toBeVisible();
    await expect(page.getByText("RPC launch matrix", { exact: true }).first()).toBeVisible();
    await expect(page.getByText("npm run flowchain:public-rpc:command-matrix").first()).toBeVisible();

    await page.goto("/activation");
    await expect(page.getByRole("heading", { name: "L1 activation" })).toBeVisible();
    await expect(page.getByLabel("L1 activation status")).toContainText("Needed now");
    await expect(page.getByLabel("L1 activation status")).toContainText("Release");
    await expect(page.getByRole("heading", { name: "Needed now" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Host apply sequence" })).toBeVisible();
    await expect(page.getByLabel("Owner host apply proof")).toContainText("owner-host-apply.sh plan");
    await expect(page.getByLabel("Owner host apply proof")).toContainText("owner-host-apply.sh apply");
    await expect(page.getByLabel("Owner host apply proof")).toContainText("owner-host-apply.ps1 -Action Plan");
    await expect(page.getByLabel("Owner host apply proof")).toContainText("owner-host-apply.ps1 -Action Apply");
    await expect(page.getByLabel("Owner host rollback commands")).toContainText("owner-host-apply.sh rollback");
    await expect(page.getByLabel("Owner host rollback commands")).toContainText("owner-host-apply.ps1 -Action Rollback");
    await expect(page.getByLabel("Go-live launch sequence")).toContainText("Apply owner-host public RPC edge");
    await expect(page.getByLabel("Next owner inputs")).toContainText("FLOWCHAIN_RPC_PUBLIC_URL");
    await expect(page.getByText("Expose repo-owned FlowChain RPC", { exact: false })).toBeVisible();
    await expect(page.getByLabel("Missing owner inputs")).toContainText("FLOWCHAIN_RPC_PUBLIC_URL");

    await page.goto("/bridge");
    await expect(page.getByRole("heading", { name: "Bridge funds into Flowchain" })).toBeVisible();
    const bridgeRuntimeProof = page.getByLabel("Bridge runtime proof");
    await expect(bridgeRuntimeProof).toContainText("Bridge command matrix");
    await expect(bridgeRuntimeProof).toContainText("flowchain:bridge:command-matrix");
    await expect(bridgeRuntimeProof).toContainText("Pilot aggregate");
    await expect(bridgeRuntimeProof).toContainText("Runtime credit");
    await expect(bridgeRuntimeProof).toContainText("Transfer settlement");
    await expect(bridgeRuntimeProof).toContainText("Relayer guardrail");
    await expect(bridgeRuntimeProof).toContainText("Relayer loop");
    await expect(bridgeRuntimeProof).toContainText(/\d+ proof commands/);
    await expect(bridgeRuntimeProof).toContainText(/\d+(\.\d+)?s to spendable credit/);
    await expect(bridgeRuntimeProof).toContainText(/\d+(\.\d+)?s/);
    await expectNoHorizontalOverflow(page);

    await page.goto("/ops");
    await expect(page.getByRole("heading", { name: "Ops center" })).toBeVisible();
    await expect(page.getByLabel("Bridge relayer check contract")).toContainText("Relayer check contract");
    await expect(page.getByLabel("Bridge relayer check contract")).toContainText("bridge-relayer-check-contract-failed");
    await expect(page.getByLabel("Service and deployment automation proof")).toContainText("Autorecovery drill");
    await expect(page.getByLabel("Service and deployment automation proof")).toContainText("Public RPC automation");
    await expect(page.getByLabel("Service and deployment automation proof")).toContainText("Systemd service plan");
    await expect(page.getByLabel("Service and deployment automation proof")).toContainText("Ops install proof");
    await expect(page.getByText("Active rules", { exact: true })).toBeVisible();
    await expect(page.getByText("Escalation dry run", { exact: true }).first()).toBeVisible();

    await page.goto("/alerts");
    await expect(page.getByRole("heading", { name: "Alerts" })).toBeVisible();
    await expect(page.getByText("Verifier failed", { exact: true })).toBeVisible();
    await expect(page.getByText("UPSTREAM_LOSS", { exact: true })).toBeVisible();
    await expect(page.getByText("next action").first()).toBeVisible();

    await page.goto("/");
    await expect(page.getByLabel("Public L1 launch readiness")).toContainText("Bridge runtime credit");
    await expect(page.getByLabel("Public L1 launch readiness")).toContainText("flowchain:bridge:runtime-credit:validate");

    await expectNoUiLeakage(page);
    await expectNoHorizontalOverflow(page);
    expect(state.unhandledRequests).toEqual([]);
    expect(consoleErrors).toEqual([]);
  });
});
