import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { AlertTriangle, CheckCircle2, Coins, RefreshCw, Send, ShieldAlert, Wallet } from "lucide-react";
import { HashValue } from "../components/HashValue";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardStatus } from "../data/types";
import {
  ZERO_METADATA_HASH,
  buildLockNativeDraft,
  candidateBridgeAccounts,
  fetchBridgeLiveSnapshot,
  generateFlowchainAccount,
  getBridgeControlPlaneUrl,
  isPlaceholderFlowchainRecipient,
  isUsableFlowchainRecipient,
  lookupBridgeCreditByTxHash,
  sendBridgeCreditTransfer,
  type BridgeCredit,
  type BridgeCreditStatus,
  type BridgeLiveSnapshot,
  type LockNativeDraft,
  type TransferSendResult,
} from "../data/bridge";

interface BridgeViewProps {
  controlPlaneUrl?: string;
  initialSnapshot?: BridgeLiveSnapshot | null;
}

type RecipientMode = "existing" | "generated" | "manual";

const DEFAULT_STATUS = {
  readinessLabel: "NOT READY",
  exposureLabel: "LOCAL ONLY",
  localOnly: true,
  livePilot: false,
  usingFixtureFallback: true,
  baseTxHash: null,
  confirmationStatus: "not_observed",
  lifecycleStatus: {
    observed: "missing",
    queued: "not_queued",
    applied: "missing",
    idempotent: "unknown",
  },
  creditedAccount: null,
  tokenId: "local-test-unit",
  amount: "0",
  spendableBalance: "0",
  balanceBreakdown: null,
  transferActionStatus: "not_run",
  firstUsableAt: null,
  latencyMs: null,
  placeholderRecipient: false,
  noBaseReleaseBroadcast: true,
  cappedOwnerTesting: true,
};

function readinessStatus(label: string | undefined, livePilot: boolean | undefined): DashboardStatus {
  if (livePilot && label === "LIVE PILOT") {
    return "verified";
  }
  if (label === "LOCAL ONLY") {
    return "pending";
  }
  return "failed";
}

function text(value: unknown, fallback = "not available"): string {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }
  return String(value);
}

function displayHash(value: string | null | undefined, label: string) {
  return value ? <HashValue value={value} label={label} trim="medium" /> : "not observed";
}

function positiveInteger(value: string): boolean {
  return /^[0-9]+$/.test(value) && BigInt(value) > 0n;
}

function withinBalance(amount: string, spendable: string | null | undefined): boolean {
  if (!positiveInteger(amount) || spendable === null || spendable === undefined || !/^[0-9]+$/.test(spendable)) {
    return false;
  }
  return BigInt(amount) <= BigInt(spendable);
}

function prettyJson(value: unknown): string {
  return JSON.stringify(value, null, 2);
}

function Fact({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

function lifecycleSummary(status: BridgeCreditStatus["lifecycleStatus"] | typeof DEFAULT_STATUS.lifecycleStatus | undefined): Array<[string, unknown]> {
  return [
    ["observed", status?.observed],
    ["queued", status?.queued],
    ["applied", status?.applied],
    ["idempotent", status?.idempotent],
  ];
}

function uniqueCreditTxHashes(credits: BridgeCredit[], fallback: string | null | undefined): string[] {
  return [
    ...new Set([
      fallback,
      ...credits.flatMap((credit) => [credit.baseTxHash, credit.txHash]),
    ].filter((value): value is string => typeof value === "string" && value.length > 0)),
  ];
}

export function BridgeView({ controlPlaneUrl = getBridgeControlPlaneUrl(), initialSnapshot = null }: BridgeViewProps) {
  const [snapshot, setSnapshot] = useState<BridgeLiveSnapshot | null>(initialSnapshot);
  const [loading, setLoading] = useState(initialSnapshot === null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [recipientMode, setRecipientMode] = useState<RecipientMode>("existing");
  const [selectedAccount, setSelectedAccount] = useState("");
  const [generatedRecipient, setGeneratedRecipient] = useState("");
  const [manualRecipient, setManualRecipient] = useState("");
  const [metadataHash, setMetadataHash] = useState(ZERO_METADATA_HASH);
  const [operatorConfirmed, setOperatorConfirmed] = useState(false);
  const [lockNativeDraft, setLockNativeDraft] = useState<LockNativeDraft | null>(null);
  const [draftError, setDraftError] = useState<string | null>(null);
  const [lookupTxHash, setLookupTxHash] = useState("");
  const [lookupResult, setLookupResult] = useState<BridgeCredit | null>(initialSnapshot?.txLookup ?? null);
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [transferTo, setTransferTo] = useState("");
  const [transferAmount, setTransferAmount] = useState("1");
  const [transferResult, setTransferResult] = useState<TransferSendResult | null>(null);
  const [transferError, setTransferError] = useState<string | null>(null);
  const [transferPending, setTransferPending] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const nextSnapshot = await fetchBridgeLiveSnapshot(controlPlaneUrl);
      setSnapshot(nextSnapshot);
      setLookupResult(nextSnapshot.txLookup);
      setLoadError(null);
    } catch (error) {
      setLoadError(error instanceof Error ? error.message : "Bridge control-plane status load failed.");
    } finally {
      setLoading(false);
    }
  }, [controlPlaneUrl]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const status = snapshot?.status ?? DEFAULT_STATUS;
  const credits = snapshot?.credits ?? [];
  const deposits = snapshot?.deposits ?? [];
  const accounts = useMemo(() => candidateBridgeAccounts(status, credits), [status, credits]);
  const creditTxHashes = useMemo(() => uniqueCreditTxHashes(credits, status.baseTxHash), [credits, status.baseTxHash]);
  const fromAccount = status.creditedAccount ?? "";
  const spendableBalance = status.spendableBalance ?? "0";
  const tokenId = status.tokenId ?? "local-test-unit";
  const readinessLabel = text(status.readinessLabel, "NOT READY");
  const exposureLabel = text(status.exposureLabel, status.localOnly ? "LOCAL ONLY" : "external exposure unknown");
  const selectedRecipient =
    recipientMode === "manual"
      ? manualRecipient.trim()
      : recipientMode === "generated"
        ? generatedRecipient
        : selectedAccount;
  const recipientValid = isUsableFlowchainRecipient(selectedRecipient);
  const canPrepareLockNative = recipientValid && operatorConfirmed && metadataHash.match(/^0x[0-9a-fA-F]{64}$/) !== null;
  const canTransfer =
    isUsableFlowchainRecipient(fromAccount)
    && isUsableFlowchainRecipient(transferTo)
    && fromAccount !== transferTo
    && withinBalance(transferAmount, spendableBalance);

  useEffect(() => {
    if (accounts.length > 0 && selectedAccount.length === 0) {
      setSelectedAccount(accounts[0]);
    }
  }, [accounts, selectedAccount]);

  useEffect(() => {
    if (lookupTxHash.length === 0 && status.baseTxHash) {
      setLookupTxHash(status.baseTxHash);
    }
  }, [lookupTxHash, status.baseTxHash]);

  const generateDepositRecipient = () => {
    const account = generateFlowchainAccount();
    setGeneratedRecipient(account);
    setRecipientMode("generated");
    setOperatorConfirmed(false);
    setLockNativeDraft(null);
    setDraftError(null);
  };

  const generateTransferRecipient = () => {
    setTransferTo(generateFlowchainAccount());
    setTransferResult(null);
    setTransferError(null);
  };

  const prepareLockNative = () => {
    setDraftError(null);
    try {
      const draft = buildLockNativeDraft(selectedRecipient, metadataHash);
      setLockNativeDraft(draft);
    } catch (error) {
      setLockNativeDraft(null);
      setDraftError(error instanceof Error ? error.message : "Unable to prepare lockNative call.");
    }
  };

  const runLookup = async () => {
    setLookupError(null);
    setLookupResult(null);
    try {
      const credit = await lookupBridgeCreditByTxHash(controlPlaneUrl, lookupTxHash.trim());
      setLookupResult(credit);
    } catch (error) {
      setLookupError(error instanceof Error ? error.message : "Bridge credit lookup failed.");
    }
  };

  const runTransfer = async () => {
    setTransferPending(true);
    setTransferError(null);
    setTransferResult(null);
    try {
      const result = await sendBridgeCreditTransfer(controlPlaneUrl, {
        from: fromAccount,
        to: transferTo.trim(),
        amount: transferAmount.trim(),
        tokenId,
        memo: "dashboard-bridge-credit-transfer-test",
      });
      setTransferResult(result);
      await refresh();
    } catch (error) {
      setTransferError(error instanceof Error ? error.message : "Transfer send failed.");
    } finally {
      setTransferPending(false);
    }
  };

  return (
    <div className="view-stack bridge-view">
      <SectionHeader
        eyebrow="flowchain bridge control plane"
        title="Live wallet and bridge credit"
        detail="Operator surface for a FlowChain recipient, live bridge credit status, tx-hash lookup, and local transfer receipt generation from the credited account."
        action={
          <button className="button" type="button" onClick={refresh} disabled={loading}>
            <RefreshCw size={15} aria-hidden="true" />
            {loading ? "Refreshing" : "Refresh"}
          </button>
        }
      />

      <section className="bridge-readiness-strip" aria-label="Bridge readiness labels">
        <article>
          <StatusBadge status={readinessStatus(readinessLabel, status.livePilot)} compact />
          <strong>{readinessLabel}</strong>
          <span>Bridge credit is considered live only when the running node reports an applied Base 8453 credit to a non-placeholder account.</span>
        </article>
        <article>
          <StatusBadge status={status.localOnly || snapshot?.health.localOnly ? "pending" : "unresolved"} compact />
          <strong>{exposureLabel}</strong>
          <span>{snapshot?.health.localOnly ? "Control-plane health reports localOnly: true." : "External exposure is not documented by this dashboard."}</span>
        </article>
        <article>
          <StatusBadge status={status.usingFixtureFallback ? "failed" : "verified"} compact />
          <strong>{status.usingFixtureFallback ? "NOT READY" : "live state loaded"}</strong>
          <span>{status.usingFixtureFallback ? "Fixture/mock fallback is visible and cannot be shown as green." : "Status came from the running control-plane."}</span>
        </article>
      </section>

      {loadError ? (
        <div className="workbench-warning" role="alert">
          <AlertTriangle size={18} aria-hidden="true" />
          <div>
            <strong>Bridge control-plane unavailable</strong>
            <span>{loadError}</span>
          </div>
        </div>
      ) : null}

      <section className="bridge-status-grid">
        <article className="panel bridge-live-panel">
          <div className="panel-heading">
            <div>
              <ShieldAlert size={18} aria-hidden="true" />
              <h2>Live credit status</h2>
            </div>
            <span>{controlPlaneUrl}</span>
          </div>
          <dl className="bridge-fact-grid">
            <Fact label="Base tx hash" value={displayHash(status.baseTxHash, "Base tx hash")} />
            <Fact label="confirmation" value={text(status.confirmationStatus)} />
            {lifecycleSummary(status.lifecycleStatus).map(([label, value]) => (
              <Fact key={label} label={label} value={text(value)} />
            ))}
            <Fact label="credited account" value={displayHash(status.creditedAccount, "credited account")} />
            <Fact label="token" value={text(tokenId)} />
            <Fact label="credited amount" value={text(status.amount, "0")} />
            <Fact label="spendable balance" value={text(status.spendableBalance, "0")} />
            <Fact label="transfer action" value={text(status.transferActionStatus)} />
            <Fact label="first usable" value={text(status.firstUsableAt)} />
            <Fact label="latency" value={status.latencyMs === null || status.latencyMs === undefined ? "not measured" : `${status.latencyMs} ms`} />
          </dl>
        </article>

        <article className="panel bridge-recipient-panel">
          <div className="panel-heading">
            <div>
              <Wallet size={18} aria-hidden="true" />
              <h2>FlowChain recipient</h2>
            </div>
            <StatusBadge status={recipientValid ? "verified" : "pending"} compact />
          </div>

          <div className="bridge-mode-grid" role="group" aria-label="Recipient source">
            <button className={recipientMode === "existing" ? "active" : ""} type="button" onClick={() => setRecipientMode("existing")}>
              Select account
            </button>
            <button className={recipientMode === "generated" ? "active" : ""} type="button" onClick={generateDepositRecipient}>
              Generate account
            </button>
            <button className={recipientMode === "manual" ? "active" : ""} type="button" onClick={() => setRecipientMode("manual")}>
              Enter account
            </button>
          </div>

          {recipientMode === "existing" ? (
            <label className="bridge-field">
              <span>Account</span>
              <select value={selectedAccount} onChange={(event) => setSelectedAccount(event.target.value)} disabled={accounts.length === 0}>
                {accounts.length === 0 ? <option value="">No non-placeholder accounts loaded</option> : null}
                {accounts.map((account) => (
                  <option key={account} value={account}>
                    {account}
                  </option>
                ))}
              </select>
            </label>
          ) : null}

          {recipientMode === "generated" ? (
            <div className="bridge-generated-account">
              <span>Generated in memory</span>
              <code>{generatedRecipient || "click Generate account"}</code>
            </div>
          ) : null}

          {recipientMode === "manual" ? (
            <label className="bridge-field">
              <span>FlowChain recipient</span>
              <input
                value={manualRecipient}
                onChange={(event) => {
                  setManualRecipient(event.target.value);
                  setOperatorConfirmed(false);
                  setLockNativeDraft(null);
                }}
                placeholder="0x followed by 64 hex characters"
              />
            </label>
          ) : null}

          <label className="bridge-field">
            <span>Metadata hash</span>
            <input value={metadataHash} onChange={(event) => setMetadataHash(event.target.value)} />
          </label>

          <div className={recipientValid ? "bridge-recipient-display valid" : "bridge-recipient-display"}>
            <strong>Recipient shown to Base wallet</strong>
            <span>{selectedRecipient || "No FlowChain recipient selected"}</span>
            {isPlaceholderFlowchainRecipient(selectedRecipient) ? <small>Placeholder recipient is refused for real-funds transfers.</small> : null}
          </div>

          <label className="bridge-confirm-line">
            <input
              type="checkbox"
              checked={operatorConfirmed}
              onChange={(event) => {
                setOperatorConfirmed(event.target.checked);
                setLockNativeDraft(null);
              }}
            />
            <span>I confirmed this exact FlowChain recipient before preparing the Base lockNative call.</span>
          </label>

          <button className="button button-primary" type="button" onClick={prepareLockNative} disabled={!canPrepareLockNative}>
            <CheckCircle2 size={15} aria-hidden="true" />
            Prepare lockNative call
          </button>
          {draftError ? <p className="bridge-error">{draftError}</p> : null}
          {lockNativeDraft ? <pre className="bridge-receipt">{prettyJson(lockNativeDraft)}</pre> : null}
        </article>
      </section>

      <section className="bridge-action-grid">
        <article className="panel bridge-lookup-panel">
          <div className="panel-heading">
            <div>
              <Coins size={18} aria-hidden="true" />
              <h2>Credit lookup</h2>
            </div>
            <span>bridge_credit_get</span>
          </div>
          <label className="bridge-field">
            <span>Base tx hash</span>
            <input list="bridge-credit-tx-hashes" value={lookupTxHash} onChange={(event) => setLookupTxHash(event.target.value)} />
            <datalist id="bridge-credit-tx-hashes">
              {creditTxHashes.map((txHash) => (
                <option key={txHash} value={txHash} />
              ))}
            </datalist>
          </label>
          <button className="button" type="button" onClick={runLookup} disabled={lookupTxHash.trim().length === 0}>
            Lookup by tx hash
          </button>
          {lookupError ? <p className="bridge-error">{lookupError}</p> : null}
          {lookupResult ? <pre className="bridge-receipt">{prettyJson({ credit: lookupResult })}</pre> : null}
        </article>

        <article className="panel bridge-transfer-panel">
          <div className="panel-heading">
            <div>
              <Send size={18} aria-hidden="true" />
              <h2>Spend credited balance</h2>
            </div>
            <span>transfer_send</span>
          </div>
          <dl className="bridge-transfer-source">
            <Fact label="from credited account" value={displayHash(fromAccount, "transfer source")} />
            <Fact label="spendable" value={`${spendableBalance} ${tokenId}`} />
          </dl>
          <label className="bridge-field">
            <span>Recipient</span>
            <input value={transferTo} onChange={(event) => setTransferTo(event.target.value)} placeholder="0x followed by 64 hex characters" />
          </label>
          <button className="button" type="button" onClick={generateTransferRecipient}>
            Generate transfer recipient
          </button>
          <label className="bridge-field bridge-amount-field">
            <span>Amount</span>
            <input inputMode="numeric" value={transferAmount} onChange={(event) => setTransferAmount(event.target.value)} />
          </label>
          <button className="button button-primary" type="button" onClick={runTransfer} disabled={!canTransfer || transferPending}>
            <Send size={15} aria-hidden="true" />
            {transferPending ? "Sending" : "Send local transfer"}
          </button>
          {transferError ? <p className="bridge-error">{transferError}</p> : null}
          {transferResult ? <pre className="bridge-receipt">{prettyJson({ receipt: transferResult.receipt ?? transferResult })}</pre> : null}
        </article>
      </section>

      <section className="panel table-panel">
        <div className="panel-heading">
          <div>
            <Coins size={18} aria-hidden="true" />
            <h2>Recent bridge records</h2>
          </div>
          <span>{credits.length} credits / {deposits.length} deposits</span>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>kind</th>
                <th>id</th>
                <th>Base tx</th>
                <th>account</th>
                <th>status</th>
                <th>amount</th>
              </tr>
            </thead>
            <tbody>
              {credits.map((credit) => (
                <tr key={`credit:${credit.creditId ?? credit.txHash ?? credit.accountId}`}>
                  <td>credit</td>
                  <td>{text(credit.creditId)}</td>
                  <td>{displayHash(credit.baseTxHash ?? credit.txHash, "credit tx hash")}</td>
                  <td>{displayHash(credit.accountId, "credit account")}</td>
                  <td>{text(credit.status)}</td>
                  <td>{text(credit.amount, "0")}</td>
                </tr>
              ))}
              {deposits.map((deposit) => (
                <tr key={`deposit:${deposit.depositId ?? deposit.txHash ?? deposit.flowchainRecipient}`}>
                  <td>deposit</td>
                  <td>{text(deposit.depositId)}</td>
                  <td>{displayHash(deposit.txHash, "deposit tx hash")}</td>
                  <td>{displayHash(deposit.flowchainRecipient, "deposit recipient")}</td>
                  <td>{text(deposit.status, "observed")}</td>
                  <td>{text(deposit.amount, "0")}</td>
                </tr>
              ))}
              {credits.length === 0 && deposits.length === 0 ? (
                <tr>
                  <td colSpan={6}>No live bridge records loaded from the control-plane.</td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
