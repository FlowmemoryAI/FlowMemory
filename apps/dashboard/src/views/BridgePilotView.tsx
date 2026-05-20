import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  ArrowRightLeft,
  ChevronDown,
  CircleDollarSign,
  Copy,
  ExternalLink,
  Info,
  ListChecks,
  Lock,
  ShieldCheck,
  Wallet,
  Zap,
} from "lucide-react";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardStatus } from "../data/types";
import type { WorkbenchSnapshot } from "../data/workbench";

type EthereumProvider = {
  request(args: { method: string; params?: unknown[] | Record<string, unknown> }): Promise<unknown>;
};

declare global {
  interface Window {
    ethereum?: EthereumProvider;
  }
}

interface BridgePilotViewProps {
  workbench: WorkbenchSnapshot;
}

type BridgeReadiness = {
  failClosedStatus?: string;
  readyForOperatorLivePilot?: boolean;
  missingEnvNames?: string[];
  issues?: Array<{ reasonCode?: string; status?: string; title?: string; summary?: string }>;
  lockbox?: { configured?: boolean; ownerVerified?: boolean };
  currentArtifacts?: { base8453DepositCount?: number };
  envValuesPrinted?: boolean;
  productionReady?: boolean;
};

const BASE_CHAIN_ID_DECIMAL = 8453;
const BASE_CHAIN_ID_HEX = "0x2105";
const BASE_RPC_URL = "https://mainnet.base.org";
const BASE_EXPLORER_URL = "https://basescan.org";
const LOCKBOX_ADDRESS = "0xe731Bc6b117d92deDCA40a7ccAec11d16205026a";
const LOCK_NATIVE_SELECTOR = "0x1326d1ec";
const MAX_DEPOSIT_WEI = 100000000000000n;
const ETH_USD_RATE_URL = "https://api.coinbase.com/v2/exchange-rates?currency=ETH";
const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";
const BLOCKED_RECIPIENT_PLACEHOLDER = "0x5555555555555555555555555555555555555555555555555555555555555555";
const BLOCKED_METADATA_PLACEHOLDER = "0x6666666666666666666666666666666666666666666666666666666666666666";
const RECIPIENT_CANDIDATE_FIELDS = new Set(["accountId", "signerId", "address", "flowchainRecipient", "recipient"]);

type BridgeRecipientOption = {
  value: string;
  label: string;
  source: string;
};

function asReadiness(value: unknown): BridgeReadiness | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as BridgeReadiness;
}

function statusFromReadiness(readiness: BridgeReadiness | null): DashboardStatus {
  if (!readiness) {
    return "pending";
  }

  if (readiness.readyForOperatorLivePilot || readiness.failClosedStatus === "READY_FOR_OPERATOR_LIVE_PILOT") {
    return "verified";
  }

  if (readiness.failClosedStatus === "FAILED") {
    return "failed";
  }

  return "pending";
}

function text(value: unknown, fallback = "not recorded"): string {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }
  return String(value);
}

function statusFromMetric(value: unknown, fallback: DashboardStatus = "pending"): DashboardStatus {
  const normalized = text(value, "").toLowerCase();
  if (normalized === "passed" || normalized === "ready" || normalized === "verified" || normalized === "true") {
    return "verified";
  }
  if (normalized === "failed" || normalized === "failure") {
    return "failed";
  }
  if (normalized === "stale") {
    return "stale";
  }
  if (normalized === "blocked" || normalized === "pending" || normalized === "false") {
    return "pending";
  }
  return fallback;
}

function secondsLabel(value: unknown): string {
  const parsed = text(value);
  return parsed === "not recorded" ? parsed : `${parsed}s`;
}

function isBytes32(value: string): boolean {
  return /^0x[0-9a-fA-F]{64}$/.test(value);
}

function isZeroBytes32(value: string): boolean {
  return /^0x0{64}$/i.test(value);
}

function normalizeInput(value: string): string {
  return value.trim();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function blockedPlaceholderLabel(value: string): string | null {
  const normalized = value.toLowerCase();
  if (normalized === BLOCKED_RECIPIENT_PLACEHOLDER) {
    return "old 0x555... placeholder";
  }
  if (normalized === BLOCKED_METADATA_PLACEHOLDER) {
    return "old 0x666... placeholder";
  }
  return null;
}

function addRecipientOption(
  options: BridgeRecipientOption[],
  seen: Set<string>,
  value: unknown,
  label: string,
  source: string,
): void {
  if (typeof value !== "string") {
    return;
  }
  const normalized = normalizeInput(value);
  if (!isBytes32(normalized) || isZeroBytes32(normalized) || blockedPlaceholderLabel(normalized)) {
    return;
  }
  const key = normalized.toLowerCase();
  if (seen.has(key)) {
    return;
  }
  seen.add(key);
  options.push({ value: normalized, label, source });
}

function collectRecipientOptionsFromRaw(
  value: unknown,
  options: BridgeRecipientOption[],
  seen: Set<string>,
  source: string,
  label: string,
  depth = 0,
): void {
  if (depth > 3) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      collectRecipientOptionsFromRaw(item, options, seen, source, `${label} ${index + 1}`, depth + 1);
    });
    return;
  }
  if (!isRecord(value)) {
    return;
  }

  for (const [key, nestedValue] of Object.entries(value)) {
    if (RECIPIENT_CANDIDATE_FIELDS.has(key)) {
      addRecipientOption(options, seen, nestedValue, label, source);
    }
    if (Array.isArray(nestedValue) || isRecord(nestedValue)) {
      collectRecipientOptionsFromRaw(nestedValue, options, seen, source, label, depth + 1);
    }
  }
}

function collectRecipientOptions(workbench: WorkbenchSnapshot): BridgeRecipientOption[] {
  const options: BridgeRecipientOption[] = [];
  const seen = new Set<string>();
  const records = [
    ...workbench.sections.walletMetadata,
    ...workbench.sections.accounts,
    ...workbench.sections.bridgeCredits,
    ...workbench.sections.bridgeDeposits,
  ];

  for (const record of records) {
    collectRecipientOptionsFromRaw(record.raw, options, seen, record.kind, record.title);
  }

  return options.slice(0, 6);
}

function validateRecipient(value: string): string | null {
  if (value.length === 0) {
    return "Enter a real Flowchain account id before bridging.";
  }
  if (!isBytes32(value)) {
    return "Recipient must be a 32-byte Flowchain account id.";
  }
  if (isZeroBytes32(value)) {
    return "Recipient cannot be the zero account id.";
  }
  const blockedLabel = blockedPlaceholderLabel(value);
  if (blockedLabel) {
    return `Recipient cannot be the ${blockedLabel}.`;
  }
  return null;
}

function validateMetadataHash(value: string): string | null {
  if (value.length === 0) {
    return null;
  }
  if (!isBytes32(value)) {
    return "Metadata hash must be blank or a bytes32 value.";
  }
  const blockedLabel = blockedPlaceholderLabel(value);
  if (blockedLabel) {
    return `Metadata hash cannot be the ${blockedLabel}.`;
  }
  return null;
}

function shorten(value: string): string {
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function parseEthToWei(value: string): { wei: bigint | null; error: string | null } {
  const trimmed = value.trim();
  if (!/^\d+(\.\d{0,18})?$/.test(trimmed)) {
    return { wei: null, error: "Use a decimal ETH amount with up to 18 decimals." };
  }

  const [wholePart, fractionPart = ""] = trimmed.split(".");
  const whole = BigInt(wholePart.length > 0 ? wholePart : "0");
  const fraction = BigInt(fractionPart.padEnd(18, "0"));
  const wei = whole * 10n ** 18n + fraction;

  if (wei <= 0n) {
    return { wei: null, error: "Amount must be greater than zero." };
  }

  if (wei > MAX_DEPOSIT_WEI) {
    return { wei: null, error: "Amount exceeds the 0.0001 ETH pilot cap." };
  }

  return { wei, error: null };
}

function parseEthDecimal(value: string): number | null {
  const trimmed = value.trim();
  if (!/^\d+(\.\d*)?$/.test(trimmed)) {
    return null;
  }

  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}

function formatUsd(value: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: value < 1 ? 4 : 2,
  }).format(value);
}

function usdEstimateFromEth(value: string, rate: number | null): string | null {
  const parsed = parseEthDecimal(value);
  if (parsed === null || rate === null) {
    return null;
  }

  return `~ ${formatUsd(parsed * rate)} USD`;
}

function toQuantityHex(value: bigint): string {
  return `0x${value.toString(16)}`;
}

function buildLockNativeData(flowchainRecipient: string, metadataHash: string): string {
  return `${LOCK_NATIVE_SELECTOR}${flowchainRecipient.slice(2)}${metadataHash.slice(2)}`;
}

async function switchToBase(provider: EthereumProvider): Promise<void> {
  try {
    await provider.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: BASE_CHAIN_ID_HEX }],
    });
  } catch (error) {
    const code = typeof error === "object" && error !== null && "code" in error ? Number((error as { code?: unknown }).code) : 0;
    if (code !== 4902) {
      throw error;
    }

    await provider.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId: BASE_CHAIN_ID_HEX,
          chainName: "Base",
          nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
          rpcUrls: [BASE_RPC_URL],
          blockExplorerUrls: [BASE_EXPLORER_URL],
        },
      ],
    });
  }
}

function errorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message;
  }

  return "Wallet request failed or was rejected.";
}

export function BridgePilotView({ workbench }: BridgePilotViewProps) {
  const readiness = asReadiness(workbench.controlPlane.bridgeLiveReadiness);
  const liveReadinessReport = isRecord(workbench.raw.liveReadinessReport) ? workbench.raw.liveReadinessReport : null;
  const liveMetrics = isRecord(liveReadinessReport?.metrics) ? liveReadinessReport.metrics : {};
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [chainId, setChainId] = useState<string | null>(null);
  const [amountEth, setAmountEth] = useState("0.00001");
  const [recipient, setRecipient] = useState("");
  const [metadataHash, setMetadataHash] = useState("");
  const [ethUsdRate, setEthUsdRate] = useState<number | null>(null);
  const [priceStatus, setPriceStatus] = useState<"loading" | "ready" | "unavailable">("loading");
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  const normalizedRecipient = normalizeInput(recipient);
  const normalizedMetadataHash = normalizeInput(metadataHash);
  const effectiveMetadataHash = normalizedMetadataHash.length === 0 ? ZERO_BYTES32 : normalizedMetadataHash;
  const amount = useMemo(() => parseEthToWei(amountEth), [amountEth]);
  const usdEstimate = useMemo(() => usdEstimateFromEth(amountEth, ethUsdRate), [amountEth, ethUsdRate]);
  const pilotCapUsdEstimate = useMemo(() => usdEstimateFromEth("0.0001", ethUsdRate), [ethUsdRate]);
  const recipientOptions = useMemo(() => collectRecipientOptions(workbench), [workbench]);
  const hardIssues = useMemo(
    () =>
      (readiness?.issues ?? []).filter(
        (issue) => issue.status === "blocked" && issue.reasonCode !== "no_deposits_observed",
      ),
    [readiness],
  );
  const missingEnvNames = readiness?.missingEnvNames ?? [];
  const validationIssue =
    amount.error ??
    validateRecipient(normalizedRecipient) ??
    validateMetadataHash(normalizedMetadataHash) ??
    (missingEnvNames.length > 0 ? `Control-plane is missing ${missingEnvNames.join(", ")}.` : null) ??
    (hardIssues.length > 0 ? hardIssues.map((issue) => issue.reasonCode ?? issue.title ?? "blocked").join(", ") : null);
  const sendDisabled = !walletAddress || validationIssue !== null;
  const readinessStatus = statusFromReadiness(readiness);
  const chainLabel = chainId === BASE_CHAIN_ID_HEX ? `Base ${BASE_CHAIN_ID_DECIMAL}` : chainId ?? "Connect wallet";
  const routeLabel = readinessStatus === "verified" ? "Verified" : "Pilot route";
  const receivedAmount = amount.wei === null ? "0 ETH" : `${amountEth || "0"} ETH`;
  const usdEstimateLabel =
    usdEstimate ??
    (priceStatus === "loading" ? "Loading ETH/USD quote" : "USD quote unavailable");
  const runtimeCreditStatus = liveMetrics.bridgeRuntimeCreditValidationStatus ?? liveMetrics.bridgeRuntimeCreditStatus;
  const pilotAggregateStatus = liveMetrics.realValuePilotAggregateStatus;
  const pilotAggregateReady = liveMetrics.realValuePilotAggregateReady === true;
  const pilotAggregateCommandCount = text(liveMetrics.realValuePilotAggregateCommandsRun, "0");
  const bridgeProofCards = [
    {
      label: "Pilot aggregate",
      value: text(pilotAggregateStatus),
      detail: `${pilotAggregateCommandCount} proof commands`,
      status: pilotAggregateReady ? "verified" : statusFromMetric(pilotAggregateStatus),
      Icon: ListChecks,
    },
    {
      label: "Runtime credit",
      value: text(runtimeCreditStatus),
      detail: `${secondsLabel(liveMetrics.bridgeRuntimeCreditLatencySeconds)} to spendable credit`,
      status: statusFromMetric(runtimeCreditStatus),
      Icon: Activity,
    },
    {
      label: "Transfer settlement",
      value: secondsLabel(liveMetrics.bridgeRuntimeCreditTransferSeconds),
      detail: "wallet credit transfer proof",
      status: liveMetrics.bridgeRuntimeCreditReady === true ? "verified" : statusFromMetric(runtimeCreditStatus),
      Icon: ArrowRightLeft,
    },
    {
      label: "Relayer guardrail",
      value: text(liveMetrics.bridgeRelayerGuardrailStatus),
      detail: "fail-closed cursor and broadcast checks",
      status: statusFromMetric(liveMetrics.bridgeRelayerGuardrailStatus),
      Icon: ShieldCheck,
    },
    {
      label: "Relayer loop",
      value: text(liveMetrics.bridgeRelayerLoopValidationStatus),
      detail: "start, health, stop, and cleanup proof",
      status: statusFromMetric(liveMetrics.bridgeRelayerLoopValidationStatus),
      Icon: ListChecks,
    },
  ] satisfies Array<{
    label: string;
    value: string;
    detail: string;
    status: DashboardStatus;
    Icon: typeof Activity;
  }>;

  useEffect(() => {
    const controller = new AbortController();

    async function loadEthUsdRate() {
      try {
        const response = await fetch(ETH_USD_RATE_URL, { signal: controller.signal });
        if (!response.ok) {
          throw new Error(`ETH/USD quote failed with ${response.status}`);
        }

        const payload = (await response.json()) as { data?: { rates?: { USD?: string } } };
        const parsed = Number(payload.data?.rates?.USD);
        if (!Number.isFinite(parsed) || parsed <= 0) {
          throw new Error("ETH/USD quote payload did not include a positive USD rate.");
        }

        setEthUsdRate(parsed);
        setPriceStatus("ready");
      } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
          return;
        }
        setPriceStatus("unavailable");
      }
    }

    void loadEthUsdRate();

    return () => controller.abort();
  }, []);

  const connectWallet = async () => {
    const provider = window.ethereum;
    if (!provider) {
      setStatusMessage("No browser wallet detected.");
      return;
    }

    try {
      const accounts = await provider.request({ method: "eth_requestAccounts" });
      const nextChainId = await provider.request({ method: "eth_chainId" });
      const accountList = Array.isArray(accounts) ? accounts : [];
      setWalletAddress(typeof accountList[0] === "string" ? accountList[0] : null);
      setChainId(typeof nextChainId === "string" ? nextChainId : null);
      setStatusMessage(null);
    } catch (error) {
      setStatusMessage(errorMessage(error));
    }
  };

  const sendDeposit = async () => {
    const provider = window.ethereum;
    if (!provider || !walletAddress || amount.wei === null || validationIssue !== null) {
      return;
    }

    try {
      setStatusMessage("Waiting for wallet confirmation.");
      setTxHash(null);
      await switchToBase(provider);
      const transactionHash = await provider.request({
        method: "eth_sendTransaction",
        params: [
          {
            from: walletAddress,
            to: LOCKBOX_ADDRESS,
            value: toQuantityHex(amount.wei),
            data: buildLockNativeData(normalizedRecipient, effectiveMetadataHash),
          },
        ],
      });
      if (typeof transactionHash === "string") {
        setTxHash(transactionHash);
        setStatusMessage("Transaction submitted on Base.");
      } else {
        setStatusMessage("Wallet returned without a transaction hash.");
      }
      const nextChainId = await provider.request({ method: "eth_chainId" });
      setChainId(typeof nextChainId === "string" ? nextChainId : null);
    } catch (error) {
      setStatusMessage(errorMessage(error));
    }
  };

  const handlePrimaryAction = walletAddress ? sendDeposit : connectWallet;
  const primaryActionLabel = walletAddress ? "Bridge to Flowchain" : "Connect wallet";

  return (
    <div className="flowchain-bridge-page">
      <div className="bridge-flow-ribbon" aria-hidden="true" />
      <header className="flowchain-bridge-nav">
        <a className="flowchain-brand" href="/" aria-label="Back to FlowMemory workbench">
          <span className="flowchain-brand-mark" aria-hidden="true">
            <span />
          </span>
          <strong>Flowchain</strong>
        </a>

        <div className="bridge-system-rail" aria-label="Bridge status">
          <button className="bridge-system-item bridge-system-wallet" type="button" onClick={connectWallet}>
            <span className="bridge-system-icon" aria-hidden="true">
              <Wallet size={21} />
            </span>
            <span>
              <strong>{walletAddress ? "Wallet connected" : "Connect wallet"}</strong>
              <small>{walletAddress ? shorten(walletAddress) : "Required"}</small>
            </span>
            <i className={walletAddress ? "is-green" : "is-amber"} aria-hidden="true" />
          </button>
          <div className="bridge-system-item">
            <span className="bridge-system-icon" aria-hidden="true">
              <ArrowRightLeft size={20} />
            </span>
            <span>
              <strong>Route available</strong>
              <small>{routeLabel}</small>
            </span>
            <i className={readinessStatus === "failed" ? "is-red" : "is-green"} aria-hidden="true" />
          </div>
          <div className="bridge-system-item">
            <span className="bridge-system-icon" aria-hidden="true">
              <ShieldCheck size={21} />
            </span>
            <span>
              <strong>Pilot mode</strong>
              <small>Capped owner pilot</small>
            </span>
            <i className="is-amber" aria-hidden="true" />
          </div>
          <a className="bridge-system-info" href="/raw" aria-label="Open raw bridge data">
            <Info size={20} aria-hidden="true" />
          </a>
        </div>
      </header>

      <main className="flowchain-bridge-main">
        <section className="bridge-title-block" aria-labelledby="bridge-title">
          <span>Cross-chain bridge</span>
          <h1 id="bridge-title">Bridge funds into Flowchain</h1>
          <p>Move assets into Flowchain. Receipt tracking and capped pilot routing.</p>
          <div className="bridge-benefit-list" aria-label="Bridge benefits">
            <article>
              <span aria-hidden="true">
                <Zap size={19} />
              </span>
              <div>
                <strong>Fast finality</strong>
                <small>Quick receipt updates.</small>
              </div>
            </article>
            <article>
              <span aria-hidden="true">
                <CircleDollarSign size={19} />
              </span>
              <div>
                <strong>Clear fee estimates</strong>
                <small>Gas shown before the wallet request.</small>
              </div>
            </article>
            <article>
              <span aria-hidden="true">
                <ShieldCheck size={19} />
              </span>
              <div>
                <strong>Wallet-safe routing</strong>
                <small>Capped pilot with wallet confirmation.</small>
              </div>
            </article>
          </div>
        </section>

        <section className="flowchain-bridge-layout" aria-label="Flowchain bridge">
          <section className="bridge-proof-rail" aria-label="Bridge runtime proof">
            <div className="bridge-proof-intro">
              <span>Bridge runtime proof</span>
              <strong>Relayer and credit checks</strong>
              <small>Latest no-secret launch evidence.</small>
            </div>
            {bridgeProofCards.map((card) => {
              const Icon = card.Icon;
              return (
                <article className="bridge-proof-item" key={card.label}>
                  <div className="bridge-proof-item-heading">
                    <span aria-hidden="true">
                      <Icon size={18} />
                    </span>
                    <StatusBadge status={card.status} compact />
                  </div>
                  <strong>{card.label}</strong>
                  <p>{card.value}</p>
                  <small>{card.detail}</small>
                </article>
              );
            })}
          </section>

          <article className="bridge-console" aria-label="Bridge transaction form">
            <div className="bridge-route-row">
              <label>
                <span>From</span>
                <small>Origin chain</small>
                <div className="bridge-select-shell">
                  <span className="bridge-chain-icon base">B</span>
                  <strong>Base</strong>
                  <ChevronDown size={16} aria-hidden="true" />
                </div>
              </label>
              <div className="bridge-route-connector" aria-hidden="true">
                <ArrowRightLeft size={20} aria-hidden="true" />
              </div>
              <label>
                <span>To</span>
                <small>Destination</small>
                <div className="bridge-select-shell">
                  <span className="bridge-chain-icon flow">F</span>
                  <strong>Flowchain</strong>
                  <Lock size={15} aria-hidden="true" />
                </div>
              </label>
            </div>

            <div className="bridge-token-amount-row">
              <div className="bridge-field bridge-token-field">
                <label htmlFor="bridge-amount">Token</label>
                <div>
                  <span className="bridge-token-orb">E</span>
                  <strong>ETH</strong>
                  <small>Base native Ether</small>
                  <ChevronDown size={16} aria-hidden="true" />
                </div>
              </div>

              <div className="bridge-field bridge-amount-field">
                <label htmlFor="bridge-amount">Amount</label>
                <input id="bridge-amount" value={amountEth} onChange={(event) => setAmountEth(event.target.value)} inputMode="decimal" />
                <span>ETH</span>
                <small className="bridge-cap-note">Pilot cap: 0.0001 ETH</small>
                <small className="bridge-usd-note">{usdEstimateLabel}</small>
                <button type="button" onClick={() => setAmountEth("0.0001")}>MAX</button>
              </div>
            </div>

            <div className="bridge-field bridge-recipient-field">
              <div className="bridge-label-row">
                <label htmlFor="bridge-recipient">Flowchain account id</label>
                <button type="button" onClick={() => setStatusMessage("Use the destination Flowchain account id. The old 0x555... placeholder is blocked.")}>
                  What is this?
                  <Info size={13} aria-hidden="true" />
                </button>
              </div>
              {recipientOptions.length > 0 ? (
                <datalist id="bridge-recipient-options">
                  {recipientOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </datalist>
              ) : null}
              <input
                id="bridge-recipient"
                list={recipientOptions.length > 0 ? "bridge-recipient-options" : undefined}
                value={recipient}
                onChange={(event) => setRecipient(event.target.value.trim())}
                placeholder="0x... 64 hex characters"
                spellCheck={false}
              />
              <button
                type="button"
                title="Copy recipient"
                disabled={normalizedRecipient.length === 0}
                onClick={() => {
                  void navigator.clipboard?.writeText(normalizedRecipient);
                  setStatusMessage("Recipient copied.");
                }}
              >
                <Copy size={15} aria-hidden="true" />
              </button>
              {recipientOptions.length > 0 ? (
                <div className="bridge-recipient-options" aria-label="Known Flowchain accounts">
                  {recipientOptions.map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      onClick={() => {
                        setRecipient(option.value);
                        setStatusMessage(`${option.source} selected.`);
                      }}
                    >
                      <span>{option.label}</span>
                      <small>{shorten(option.value)}</small>
                    </button>
                  ))}
                </div>
              ) : null}
            </div>

            <div className="bridge-estimate-grid">
              <div className="bridge-estimate-primary">
                <span>
                  You will send
                  <Info size={13} aria-hidden="true" />
                </span>
                <strong>{receivedAmount}</strong>
                <small>{usdEstimateLabel}</small>
              </div>
              <div>
                <span>
                  Route
                  <Info size={13} aria-hidden="true" />
                </span>
                <strong>Base to FlowChain</strong>
                <StatusBadge status={readinessStatus} compact />
              </div>
              <div>
                <span>
                  Network fee est.
                  <Info size={13} aria-hidden="true" />
                </span>
                <strong>Wallet gas</strong>
                <small>{chainLabel}</small>
              </div>
              <div>
                <span>
                  Bridge fee
                  <Info size={13} aria-hidden="true" />
                </span>
                <strong>No protocol fee</strong>
                <small>Capped pilot route</small>
              </div>
              <div>
                <span>
                  ETA
                  <Info size={13} aria-hidden="true" />
                </span>
                <strong>After confirmations</strong>
              </div>
              <div>
                <span>
                  Pilot cap
                  <Info size={13} aria-hidden="true" />
                </span>
                <strong>0.0001 ETH</strong>
                {pilotCapUsdEstimate ? <small>{pilotCapUsdEstimate}</small> : null}
              </div>
            </div>

            <details className="bridge-advanced">
              <summary>
                <span>Advanced details (metadata / bytes32 recipient)</span>
                <ChevronDown size={16} aria-hidden="true" />
              </summary>
              <div className="bridge-advanced-body">
                <div className="bridge-field bridge-recipient-field">
                  <label htmlFor="bridge-metadata">Metadata hash</label>
                  <input
                    id="bridge-metadata"
                    value={metadataHash}
                    onChange={(event) => setMetadataHash(event.target.value.trim())}
                    placeholder="Blank sends 0x000...000"
                    spellCheck={false}
                  />
                </div>
              </div>
              <dl className="bridge-calldata-facts">
                <div>
                  <dt>call</dt>
                  <dd>lockNative(bytes32,bytes32)</dd>
                </div>
                <div>
                  <dt>lockbox</dt>
                  <dd>{shorten(LOCKBOX_ADDRESS)}</dd>
                </div>
                <div>
                  <dt>chain</dt>
                  <dd>{chainLabel}</dd>
                </div>
              </dl>
            </details>

            <div className="bridge-action-row">
              <button className="bridge-primary-action" type="button" onClick={handlePrimaryAction} disabled={walletAddress ? sendDisabled : false}>
                {primaryActionLabel}
                <ArrowRightLeft size={18} aria-hidden="true" />
              </button>
            </div>

            <div className="bridge-terms-row">
              <ShieldCheck size={16} aria-hidden="true" />
              <span>By proceeding, you acknowledge this is a capped owner pilot and agree to the pilot terms.</span>
            </div>

            {validationIssue ? (
              <p className="bridge-validation">
                <AlertTriangle size={16} aria-hidden="true" />
                {validationIssue}
              </p>
            ) : null}
            {statusMessage ? <p className="bridge-status-message">{statusMessage}</p> : null}
            {txHash ? (
              <a className="bridge-tx-link" href={`${BASE_EXPLORER_URL}/tx/${txHash}`} target="_blank" rel="noreferrer">
                {shorten(txHash)}
                <ExternalLink size={14} aria-hidden="true" />
              </a>
            ) : null}

            <div className="bridge-safety-rail">
              <span>
                <ShieldCheck size={18} aria-hidden="true" />
                Secured by FlowMemory infrastructure
              </span>
              <a href="/raw">
                Learn more
                <ExternalLink size={14} aria-hidden="true" />
              </a>
              <a href={`${BASE_EXPLORER_URL}/address/${LOCKBOX_ADDRESS}`} target="_blank" rel="noreferrer">
                View transaction history
                <ExternalLink size={14} aria-hidden="true" />
              </a>
            </div>
          </article>
        </section>
      </main>
    </div>
  );
}
