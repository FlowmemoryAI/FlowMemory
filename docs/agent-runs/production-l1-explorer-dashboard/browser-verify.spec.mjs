import { test, expect } from "@playwright/test";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const evidenceDir = resolve("docs/agent-runs/production-l1-explorer-dashboard");
const dashboardUrl = process.env.FLOWCHAIN_DASHBOARD_URL ?? "http://127.0.0.1:5173";

const requiredLabels = [
  "Node and API status",
  "Blocks",
  "Transactions",
  "Receipts / Events",
  "Accounts",
  "Balances",
  "Token Launch",
  "Token Balances",
  "Token Transfers",
  "DEX Pools",
  "Liquidity",
  "Swaps",
  "Bridge Deposits",
  "Bridge Credits",
  "Bridge Withdrawals",
  "Bridge Releases",
  "Errors / Recovery",
  "Raw JSON",
  "8453",
];

const searchTerms = {
  baseTxHash: "0x2222222222222222222222222222222222222222222222222222222222222222",
  bridgeObservationId: "0x0430f0f7818add19ccd9037dcf6e50d75c1fb0fac0441f9b042c473d1d2d223c",
  bridgeCreditId: "0xff3efb8221533cfc836bffbcee10bdd2d7d4a5615efce9516574245a3b7d74a6",
  creditedAccount: "0x5555555555555555555555555555555555555555555555555555555555555555",
  localTransferTxId: "0x3ac0b196a212a0e77d0a0c4b60e2283d2994b09993971b95427996700f5b92aa",
  swapTxId: "0xa0729982b58cc701aba6af0bc29ca993190db4e8e1489af918dbe293c0c03bad",
  withdrawalIntentId: "0xe6f0da66dc9659e427640f119b24a83b01ccb2f79c745d6d4c28570c5e5e1751",
  releaseEvidenceId: "0x7e3a7f7ab7dc9b07d762c1f2fce315cf0c08f1a7e854b4dbcb2359efcb9cb278",
};

async function collectEvidence(page, viewportName) {
  const bodyText = await page.locator("body").innerText();
  const required = Object.fromEntries(requiredLabels.map((label) => [label, bodyText.includes(label)]));
  const layout = await page.evaluate(() => {
    const clippedByScrollableAncestor = (element, rect) => {
      let parent = element.parentElement;
      while (parent) {
        const style = window.getComputedStyle(parent);
        const overflow = `${style.overflow} ${style.overflowX} ${style.overflowY}`;
        if (/(auto|scroll|hidden|clip)/.test(overflow)) {
          const parentRect = parent.getBoundingClientRect();
          if (rect.bottom <= parentRect.top || rect.top >= parentRect.bottom || rect.right <= parentRect.left || rect.left >= parentRect.right) {
            return true;
          }
        }
        parent = parent.parentElement;
      }
      return false;
    };
    const boxes = Array.from(document.querySelectorAll("button, input, select, textarea, [role='button'], article, section, pre"))
      .map((element) => {
        const rect = element.getBoundingClientRect();
        if (clippedByScrollableAncestor(element, rect)) {
          return null;
        }
        return {
          element,
          tag: element.tagName.toLowerCase(),
          text: (element.textContent ?? "").trim().slice(0, 80),
          left: rect.left,
          top: rect.top,
          right: rect.right,
          bottom: rect.bottom,
          width: rect.width,
          height: rect.height,
        };
      })
      .filter((box) => box !== null)
      .filter((box) => box.width > 0 && box.height > 0);
    const overlaps = [];
    for (let leftIndex = 0; leftIndex < boxes.length; leftIndex += 1) {
      for (let rightIndex = leftIndex + 1; rightIndex < boxes.length; rightIndex += 1) {
        const left = boxes[leftIndex];
        const right = boxes[rightIndex];
        if (left.element.contains(right.element) || right.element.contains(left.element)) {
          continue;
        }
        const xOverlap = Math.min(left.right, right.right) - Math.max(left.left, right.left);
        const yOverlap = Math.min(left.bottom, right.bottom) - Math.max(left.top, right.top);
        if (xOverlap > 8 && yOverlap > 8 && left.text && right.text && !left.text.includes(right.text) && !right.text.includes(left.text)) {
          const { element: leftElement, ...leftBox } = left;
          const { element: rightElement, ...rightBox } = right;
          overlaps.push({ left: leftBox, right: rightBox, xOverlap, yOverlap });
        }
      }
    }
    return {
      viewport: { width: window.innerWidth, height: window.innerHeight },
      document: {
        scrollWidth: document.documentElement.scrollWidth,
        clientWidth: document.documentElement.clientWidth,
        scrollHeight: document.documentElement.scrollHeight,
      },
      tableScrollContainers: Array.from(document.querySelectorAll(".workbench-table-wrap, .raw-json, pre")).map((element) => ({
        className: element.className,
        scrollWidth: element.scrollWidth,
        clientWidth: element.clientWidth,
      })),
      localStorageKeys: Object.keys(window.localStorage),
      sessionStorageKeys: Object.keys(window.sessionStorage),
      secretShapedInputs: Array.from(document.querySelectorAll("input, textarea"))
        .map((element) => `${element.getAttribute("name") ?? ""} ${element.getAttribute("placeholder") ?? ""} ${element.getAttribute("aria-label") ?? ""}`.trim())
        .filter((label) => /private|seed|mnemonic|rpc|api key|webhook|vault password/i.test(label)),
      overlaps: overlaps.slice(0, 20),
    };
  });

  return { viewportName, required, layout };
}

test("FlowChain dashboard renders explorer surfaces and search paths", async ({ page }) => {
  await mkdir(evidenceDir, { recursive: true });
  const consoleErrors = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });
  page.on("pageerror", (error) => {
    consoleErrors.push(error.message);
  });

  await page.setViewportSize({ width: 1440, height: 1100 });
  await page.goto(dashboardUrl, { waitUntil: "networkidle" });
  await page.screenshot({ path: resolve(evidenceDir, "dashboard-desktop-playwright.png"), fullPage: true });
  const desktop = await collectEvidence(page, "desktop-1440x1100");
  const realValuePilotSwitch = page.locator(".workbench-switch").filter({ hasText: "Real-value pilot" });
  await expect(realValuePilotSwitch).toHaveCount(1);
  await realValuePilotSwitch.click();
  const realValuePilotText = await page.locator(".workbench-record-panel").innerText();

  const searchInput = page.getByPlaceholder("Search blocks, txs, accounts, tokens, pools, bridge evidence");
  await expect(searchInput).toBeVisible();
  const searches = {};
  for (const [label, term] of Object.entries(searchTerms)) {
    await searchInput.fill(term);
    await page.waitForTimeout(75);
    const bodyText = await page.locator("body").innerText();
    const resultCount = await page.locator(".workbench-record").count();
    searches[label] = {
      term,
      visible: bodyText.includes("Search Results") && resultCount > 0,
      resultCount,
    };
  }

  await page.setViewportSize({ width: 390, height: 900 });
  await page.reload({ waitUntil: "networkidle" });
  await page.screenshot({ path: resolve(evidenceDir, "dashboard-mobile-playwright.png"), fullPage: true });
  const mobile = await collectEvidence(page, "mobile-390x900");

  const evidence = {
    url: dashboardUrl,
    title: await page.title(),
    generatedAt: new Date().toISOString(),
    consoleErrors,
    desktop,
    mobile,
    realValuePilotTextIncludesBaseReadiness: /pilot/i.test(realValuePilotText) && realValuePilotText.includes("8453"),
    searches,
  };
  await writeFile(resolve(evidenceDir, "browser-dom-evidence.json"), `${JSON.stringify(evidence, null, 2)}\n`);

  expect(consoleErrors).toEqual([]);
  expect(Object.values(desktop.required).every(Boolean)).toBe(true);
  expect(Object.values(mobile.required).every(Boolean)).toBe(true);
  expect(evidence.realValuePilotTextIncludesBaseReadiness).toBe(true);
  expect(Object.values(searches).every((result) => result.visible)).toBe(true);
  expect(desktop.layout.secretShapedInputs).toEqual([]);
  expect(mobile.layout.secretShapedInputs).toEqual([]);
  expect(desktop.layout.localStorageKeys).toEqual([]);
  expect(mobile.layout.localStorageKeys).toEqual([]);
  expect(desktop.layout.overlaps).toEqual([]);
  expect(mobile.layout.overlaps).toEqual([]);
});
