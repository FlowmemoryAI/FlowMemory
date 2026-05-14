import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  Activity,
  AlertTriangle,
  ArrowRight,
  ArrowRightLeft,
  BadgeCheck,
  Bell,
  ChevronDown,
  ChevronRight,
  CircleDollarSign,
  Cloud,
  Copy,
  Download,
  ExternalLink,
  Eye,
  Home,
  KeyRound,
  Lock,
  Network,
  RefreshCw,
  Search,
  Send,
  Settings,
  ShieldCheck,
  SlidersHorizontal,
  Wallet,
} from "lucide-react";
import type { WorkbenchSnapshot } from "../data/workbench";

type WalletAccount = {
  accountId?: string;
  address?: string;
  signerId?: string;
  signerKeyId?: string;
  keyScheme?: string;
  label?: string;
  status?: string;
  chainId?: string;
  nextNonce?: string;
};

type WalletStatus = {
  schema?: string;
  exists?: boolean;
  account?: WalletAccount | null;
  accounts?: WalletAccount[];
  metadataPath?: string;
  secretMaterialReturned?: boolean;
};

type WalletCreateResult = WalletStatus & {
  created?: boolean;
  alreadyExists?: boolean;
  vaultPath?: string;
  note?: string;
  message?: string;
};

type WalletBalance = {
  balanceId?: string;
  walletAddress?: string;
  asset?: string;
  amount?: string;
  creditedAmount?: string;
  creditId?: string;
  depositId?: string;
  status?: string;
  source?: string;
};

type WalletSendResult = {
  schema?: string;
  accepted?: boolean;
  applied?: boolean;
  transferId?: string;
  txIds?: string[];
  amountUnits?: string;
  status?: string;
  from?: {
    requestedAccountId?: string;
    runtimeAccountId?: string;
    resolution?: string;
  };
  to?: {
    requestedAccountId?: string;
    runtimeAccountId?: string;
    resolution?: string;
  };
  message?: string;
};

type WalletTransfer = {
  transferId?: string;
  txId?: string;
  fromAccountId?: string;
  toAccountId?: string;
  assetId?: string;
  amount?: string;
  status?: string;
  source?: string;
};

type PilotCredit = {
  creditId?: string;
  depositId?: string;
  accountId?: string;
  amount?: string;
  token?: string;
  status?: string;
  txHash?: string;
  sourceChainId?: number;
};

type BridgeStatus = {
  deposits?: number;
  credits?: number;
  applied?: number;
  pending?: number;
  productionReadyCredits?: number;
  publicProductionL1Ready?: boolean;
  liveRuntimeHandoffLoaded?: boolean;
};

type WalletApiResult<T> = {
  payload: T;
  url: string;
};

type ActionPanel = "home" | "wallet" | "send" | "receive" | "swap" | "activity" | "security" | "settings" | "staking";

type LocalActivity = {
  id: string;
  type: string;
  asset: string;
  route: string;
  amount: string;
  status: string;
};

interface WalletViewProps {
  workbench: WorkbenchSnapshot;
}

class WalletApiError extends Error {
  status?: number;
  url?: string;
}

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ETH_USD_RATE_URL = "https://api.coinbase.com/v2/exchange-rates?currency=ETH";

function shortId(value: string, head = 6, tail = 4): string {
  return value.length > head + tail + 5 ? `${value.slice(0, head)}...${value.slice(-tail)}` : value;
}

function safeText(value: unknown, fallback = "not available"): string {
  return typeof value === "string" && value.length > 0 ? value : fallback;
}

function accountId(account: WalletAccount | null | undefined): string {
  return safeText(account?.accountId ?? account?.address ?? account?.signerId, "");
}

function isLoopbackHost(value: string): boolean {
  return value === "127.0.0.1" || value === "localhost" || value === "::1";
}

function walletApiCandidates(primaryUrl: string): string[] {
  const candidates: string[] = [];
  const browserHost = typeof window !== "undefined" ? window.location.hostname : "";

  if (browserHost && !isLoopbackHost(browserHost)) {
    candidates.push(`http://${browserHost}:8795`, `http://${browserHost}:8794`, `http://${browserHost}:8787`);
  }

  candidates.push(primaryUrl);

  if (!browserHost || isLoopbackHost(browserHost)) {
    candidates.push("http://127.0.0.1:8794", "http://127.0.0.1:8795", "http://127.0.0.1:8787");
  }

  return [...new Set(candidates.map((candidate) => candidate.replace(/\/+$/, "")))];
}

async function readJsonPayload(response: Response): Promise<unknown> {
  const body = await response.text();
  if (body.trim().length === 0) {
    return {};
  }
  try {
    return JSON.parse(body) as unknown;
  } catch {
    return { message: body };
  }
}

async function fetchWalletApi<T>(urls: string[], path: string, init?: RequestInit): Promise<WalletApiResult<T>> {
  let lastError: Error | null = null;

  for (const url of urls) {
    try {
      const response = await fetch(`${url}${path}`, init);
      const payload = await readJsonPayload(response);
      if (!response.ok) {
        const error = new WalletApiError(safeText((payload as { message?: string }).message, `${path} failed with ${response.status}`));
        error.status = response.status;
        error.url = url;
        lastError = error;
        if (response.status === 404) {
          continue;
        }
        throw error;
      }
      return { payload: payload as T, url };
    } catch (error) {
      lastError = error instanceof Error ? error : new Error("wallet API unavailable");
      if (error instanceof WalletApiError && error.status !== 404) {
        throw error;
      }
    }
  }

  throw lastError ?? new Error("wallet API unavailable");
}

function weiToEth(value: string | undefined): number {
  if (!value || !/^\d+$/.test(value)) {
    return 0;
  }
  return Number(value) / 1e18;
}

function formatEth(value: number): string {
  if (value === 0) {
    return "0 ETH";
  }
  if (value < 0.0001) {
    return `${value.toFixed(8).replace(/0+$/, "").replace(/\.$/, "")} ETH`;
  }
  return `${value.toLocaleString(undefined, { maximumFractionDigits: 6 })} ETH`;
}

function formatUsd(value: number): string {
  return value.toLocaleString(undefined, {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: value >= 1 ? 2 : 4,
    maximumFractionDigits: value >= 1 ? 2 : 4,
  });
}

function formatAssetAddress(asset: string | undefined): string {
  if (!asset || asset.toLowerCase() === ZERO_ADDRESS) {
    return "ETH";
  }
  return shortId(asset, 5, 4);
}

function statusLabel(value: string | undefined): string {
  return value ? value.replace(/_/g, " ") : "pending";
}

function timestampLabel(): string {
  return new Date().toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function FlowMark() {
  return (
    <span className="wallet-flow-mark" aria-hidden="true">
      <span />
    </span>
  );
}

export function WalletView({ workbench }: WalletViewProps) {
  const controlPlaneUrl = workbench.controlPlane.url;
  const apiCandidates = useMemo(() => walletApiCandidates(controlPlaneUrl), [controlPlaneUrl]);
  const [walletApiUrl, setWalletApiUrl] = useState(controlPlaneUrl);
  const [status, setStatus] = useState<WalletStatus | null>(null);
  const [result, setResult] = useState<WalletCreateResult | null>(null);
  const [balances, setBalances] = useState<WalletBalance[]>([]);
  const [transfers, setTransfers] = useState<WalletTransfer[]>([]);
  const [credits, setCredits] = useState<PilotCredit[]>([]);
  const [bridgeStatus, setBridgeStatus] = useState<BridgeStatus | null>(null);
  const [ethUsdRate, setEthUsdRate] = useState<number | null>(null);
  const [label, setLabel] = useState("flow-wallet");
  const [passphrase, setPassphrase] = useState("");
  const [replace, setReplace] = useState(false);
  const [sendTo, setSendTo] = useState("");
  const [sendAmount, setSendAmount] = useState("");
  const [swapAmount, setSwapAmount] = useState("");
  const [search, setSearch] = useState("");
  const [activePanel, setActivePanel] = useState<ActionPanel>("home");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [localActivity, setLocalActivity] = useState<LocalActivity[]>([]);

  const activeAccount = result?.account ?? status?.account ?? null;
  const activeAccountId = accountId(activeAccount);
  const primaryBalance = balances.find((balance) => balance.status === "credited") ?? balances[0] ?? null;
  const primaryWalletAddress = safeText(primaryBalance?.walletAddress, activeAccountId || "");
  const totalEth = balances.reduce((sum, balance) => sum + weiToEth(balance.amount ?? balance.creditedAmount), 0);
  const totalUsd = totalEth * (ethUsdRate ?? 0);
  const hasWallet = Boolean(activeAccountId || primaryWalletAddress);
  const networkBadge = bridgeStatus?.publicProductionL1Ready ? "Live" : bridgeStatus?.liveRuntimeHandoffLoaded ? "Pilot" : "Local";
  const canCreate = passphrase.length >= 8 && !loading;
  const visibleCredits = credits.filter((credit) =>
    credit.sourceChainId === 8453 || credit.accountId === primaryWalletAddress || credit.status === "applied",
  );
  const filteredCredits = visibleCredits.filter((credit) => {
    const query = search.trim().toLowerCase();
    if (query.length === 0) {
      return true;
    }
    return [credit.creditId, credit.txHash, credit.accountId, credit.status].some((value) => String(value ?? "").toLowerCase().includes(query));
  });

  async function copyValue(value: string, nextMessage: string) {
    if (!value) {
      return;
    }
    await navigator.clipboard?.writeText(value);
    setMessage(nextMessage);
  }

  async function loadStatus() {
    try {
      const [walletResult, balanceResult, transferResult, creditResult, bridgeResult] = await Promise.all([
        fetchWalletApi<WalletStatus>(apiCandidates, "/wallets/operator"),
        fetchWalletApi<{ balances?: WalletBalance[] }>(apiCandidates, "/wallets/balances"),
        fetchWalletApi<{ transfers?: WalletTransfer[] }>(apiCandidates, "/wallets/transfers"),
        fetchWalletApi<{ credits?: PilotCredit[] }>(apiCandidates, "/pilot/credits?limit=10"),
        fetchWalletApi<BridgeStatus>(apiCandidates, "/bridge/status"),
      ]);
      setWalletApiUrl(walletResult.url);
      setStatus(walletResult.payload);
      setBalances(balanceResult.payload.balances ?? []);
      setTransfers(transferResult.payload.transfers ?? []);
      setCredits(creditResult.payload.credits ?? []);
      setBridgeStatus(bridgeResult.payload);
      setMessage(null);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "wallet data unavailable");
    }
  }

  useEffect(() => {
    void loadStatus();
  }, [apiCandidates]);

  useEffect(() => {
    let cancelled = false;
    fetch(ETH_USD_RATE_URL, { cache: "no-store" })
      .then((response) => response.json() as Promise<{ data?: { rates?: { USD?: string } } }>)
      .then((payload) => {
        if (!cancelled) {
          const rate = Number(payload.data?.rates?.USD);
          setEthUsdRate(Number.isFinite(rate) ? rate : null);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setEthUsdRate(null);
        }
      });
    return () => {
      cancelled = true;
    };
  }, []);

  async function createWallet() {
    if (!canCreate) {
      return;
    }
    setLoading(true);
    setMessage(null);
    try {
      const { payload, url } = await fetchWalletApi<WalletCreateResult>(apiCandidates, "/wallets/create", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          label,
          password: passphrase,
          chainId: "31337",
          replace,
        }),
      });
      setWalletApiUrl(url);
      setResult(payload);
      setStatus(payload);
      setPassphrase("");
      setActivePanel("receive");
      setMessage(payload.alreadyExists ? safeText(payload.note, "Existing wallet loaded.") : "Wallet created.");
      await loadStatus();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "wallet creation failed");
    } finally {
      setLoading(false);
    }
  }

  async function submitSend() {
    if (!sendTo.trim() || !sendAmount.trim()) {
      setMessage("Enter a recipient and amount first.");
      return;
    }
    setLoading(true);
    setMessage(null);
    try {
      const { payload, url } = await fetchWalletApi<WalletSendResult>(apiCandidates, "/wallets/send", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          fromAccountId: primaryWalletAddress,
          toAccountId: sendTo.trim(),
          amountEth: sendAmount.trim(),
          memo: "flowchain-wallet-ui-send",
        }),
      });
      setWalletApiUrl(url);
      setLocalActivity((current) => [
        {
          id: payload.transferId ?? `send:${Date.now()}`,
          type: payload.applied ? "Send applied" : "Send queued",
          asset: "ETH",
          route: `${shortId(payload.from?.runtimeAccountId ?? primaryWalletAddress)} to ${shortId(payload.to?.runtimeAccountId ?? sendTo)}`,
          amount: `-${sendAmount} ETH`,
          status: statusLabel(payload.status),
        },
        ...current,
      ]);
      setSendTo("");
      setSendAmount("");
      setActivePanel("activity");
      setMessage(payload.applied ? "Send applied on Flowchain runtime." : "Send queued for Flowchain runtime.");
      await loadStatus();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "wallet send failed");
    } finally {
      setLoading(false);
    }
  }

  function submitSwapDraft() {
    if (!swapAmount.trim()) {
      setMessage("Enter a swap amount first.");
      return;
    }
    setLocalActivity((current) => [
      {
        id: `swap:${Date.now()}`,
        type: "Swap quoted",
        asset: "ETH to FLOW",
        route: "Flowchain local quote",
        amount: `${swapAmount} ETH`,
        status: "Quote ready",
      },
      ...current,
    ]);
    setSwapAmount("");
    setActivePanel("activity");
    setMessage("Swap quote prepared. A live DEX execution endpoint is not connected to this wallet screen yet.");
  }

  const assetRows = balances.length > 0
    ? balances.map((balance) => {
        const eth = weiToEth(balance.amount ?? balance.creditedAmount);
        return {
          key: balance.balanceId ?? `${balance.walletAddress}:${balance.asset}`,
          name: formatAssetAddress(balance.asset),
          description: balance.source === "bridge-credit" ? "Base bridged Ether" : "Flowchain asset",
          balance: formatEth(eth),
          value: ethUsdRate ? formatUsd(eth * ethUsdRate) : "USD quote unavailable",
          change: balance.status === "credited" ? "+ credited" : statusLabel(balance.status),
          tone: "up",
        };
      })
    : [
        {
          key: "empty-eth",
          name: "ETH",
          description: "No credited balance",
          balance: "0 ETH",
          value: "$0.00",
          change: "0.00%",
          tone: "flat",
        },
      ];

  const activityRows = [
    ...localActivity,
    ...filteredCredits.map((credit) => ({
      id: credit.creditId ?? `${credit.txHash}:${credit.amount}`,
      type: credit.status === "applied" ? "Bridge credit" : "Bridge pending",
      asset: formatAssetAddress(credit.token),
      route: credit.txHash ? shortId(credit.txHash, 8, 6) : "Flowchain",
      amount: `${formatEth(weiToEth(credit.amount))}`,
      status: statusLabel(credit.status),
    })),
    ...transfers.map((transfer) => ({
      id: transfer.transferId ?? transfer.txId ?? `${transfer.fromAccountId}:${transfer.toAccountId}`,
      type: "Transfer",
      asset: safeText(transfer.assetId, "asset"),
      route: `${shortId(safeText(transfer.fromAccountId, "from"))} to ${shortId(safeText(transfer.toAccountId, "to"))}`,
      amount: safeText(transfer.amount, "0"),
      status: statusLabel(transfer.status),
    })),
  ];

  return (
    <div className="wallet-app-shell">
      <aside className="wallet-app-sidebar" aria-label="Wallet navigation">
        <Link className="wallet-brand" to="/wallet" aria-label="Flowchain wallet home">
          <FlowMark />
          <strong>Flowchain</strong>
        </Link>

        <nav className="wallet-side-nav">
          <button className={activePanel === "home" ? "active" : ""} type="button" onClick={() => setActivePanel("home")}>
            <Home size={19} aria-hidden="true" />
            Home
          </button>
          <button className={activePanel === "wallet" || activePanel === "receive" ? "active" : ""} type="button" onClick={() => setActivePanel("wallet")}>
            <Wallet size={19} aria-hidden="true" />
            Wallet
          </button>
          <button className={activePanel === "activity" ? "active" : ""} type="button" onClick={() => setActivePanel("activity")}>
            <Activity size={19} aria-hidden="true" />
            Activity
          </button>
          <Link to="/bridge">
            <Network size={19} aria-hidden="true" />
            Bridge
          </Link>
          <button className={activePanel === "swap" ? "active" : ""} type="button" onClick={() => setActivePanel("swap")}>
            <ArrowRightLeft size={19} aria-hidden="true" />
            Swap
          </button>
          <button className={activePanel === "staking" ? "active" : ""} type="button" onClick={() => setActivePanel("staking")}>
            <CircleDollarSign size={19} aria-hidden="true" />
            Staking
          </button>
          <button className={activePanel === "security" ? "active" : ""} type="button" onClick={() => setActivePanel("security")}>
            <ShieldCheck size={19} aria-hidden="true" />
            Security
          </button>
          <button className={activePanel === "settings" ? "active" : ""} type="button" onClick={() => setActivePanel("settings")}>
            <Settings size={19} aria-hidden="true" />
            Settings
          </button>
        </nav>

        <button className="wallet-collapse-button" type="button" onClick={() => setMessage("Sidebar collapse is cosmetic in this local wallet build.")}>
          <ChevronRight size={18} aria-hidden="true" />
          Collapse
        </button>
      </aside>

      <main className="wallet-app-main">
        <header className="wallet-app-topbar">
          <button className="wallet-network-switch" type="button" onClick={() => setMessage(`Wallet API: ${walletApiUrl}`)}>
            <span><FlowMark /></span>
            Flowchain
            <ChevronDown size={16} aria-hidden="true" />
          </button>

          <label className="wallet-search">
            <Search size={18} aria-hidden="true" />
            <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search anything..." />
            <kbd>Ctrl K</kbd>
          </label>

          <button className="wallet-icon-button" type="button" aria-label="Notifications" onClick={() => setMessage("No new wallet alerts.")}>
            <Bell size={21} aria-hidden="true" />
            <span />
          </button>

          <button className="wallet-profile-pill" type="button" onClick={() => setActivePanel("receive")}>
            <span>F1</span>
            <strong>Flow Wallet</strong>
            <small>{primaryWalletAddress ? shortId(primaryWalletAddress, 5, 4) : "Create wallet"}</small>
            <ChevronDown size={16} aria-hidden="true" />
          </button>
        </header>

        <section className="wallet-portfolio-panel">
          <div className="wallet-portfolio-copy">
            <h1>Portfolio</h1>
            <span>
              Total balance
              <Eye size={17} aria-hidden="true" />
            </span>
            <strong>{ethUsdRate ? formatUsd(totalUsd) : formatEth(totalEth)}</strong>
            <p>
              <b>{formatEth(totalEth)}</b>
              <small>{ethUsdRate ? `${formatUsd(totalUsd)} estimated` : "USD quote unavailable"}</small>
            </p>
          </div>

          <div className="wallet-chart-card" aria-label="Portfolio chart">
            <div className="wallet-chart-tabs">
              {["1D", "7D", "30D", "90D", "1Y", "ALL"].map((range) => (
                <button key={range} className={range === "1D" ? "active" : ""} type="button">
                  {range}
                </button>
              ))}
            </div>
            <svg viewBox="0 0 560 190" role="img" aria-label="Portfolio trend line">
              <defs>
                <linearGradient id="walletChartFill" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0%" stopColor="#0f5fff" stopOpacity="0.24" />
                  <stop offset="100%" stopColor="#0f5fff" stopOpacity="0" />
                </linearGradient>
              </defs>
              <path className="wallet-chart-fill" d="M22 132 C54 118, 74 122, 103 90 S158 81, 181 76 S235 94, 266 73 S326 82, 356 66 S412 82, 444 58 S499 48, 538 29 L538 168 L22 168 Z" />
              <path className="wallet-chart-line" d="M22 132 C54 118, 74 122, 103 90 S158 81, 181 76 S235 94, 266 73 S326 82, 356 66 S412 82, 444 58 S499 48, 538 29" />
              <g className="wallet-chart-grid">
                <path d="M22 48H538" />
                <path d="M22 88H538" />
                <path d="M22 128H538" />
                <path d="M22 168H538" />
              </g>
            </svg>
            <div className="wallet-chart-axis">
              <span>00:00</span>
              <span>04:00</span>
              <span>08:00</span>
              <span>12:00</span>
              <span>16:00</span>
              <span>20:00</span>
              <span>24:00</span>
            </div>
          </div>
        </section>

        <section className="wallet-action-grid" aria-label="Wallet actions">
          <button type="button" onClick={() => setActivePanel("send")}>
            <span><Send size={21} aria-hidden="true" /></span>
            <strong>Send</strong>
            <small>Send tokens</small>
          </button>
          <button type="button" onClick={() => setActivePanel("receive")}>
            <span><Download size={22} aria-hidden="true" /></span>
            <strong>Receive</strong>
            <small>Receive tokens</small>
          </button>
          <button type="button" onClick={() => setActivePanel("swap")}>
            <span><ArrowRightLeft size={22} aria-hidden="true" /></span>
            <strong>Swap</strong>
            <small>Swap assets</small>
          </button>
          <Link to="/bridge">
            <span><Network size={22} aria-hidden="true" /></span>
            <strong>Bridge</strong>
            <small>Bridge to Flowchain</small>
          </Link>
        </section>

        <section className="wallet-assets-section">
          <div className="wallet-section-title">
            <h2>Assets</h2>
            <button type="button" onClick={() => setActivePanel("wallet")}>
              View all assets
              <ChevronRight size={16} aria-hidden="true" />
            </button>
          </div>
          <div className="wallet-asset-table" role="table" aria-label="Assets">
            <div role="row">
              <span>Asset</span>
              <span>Balance</span>
              <span>Value (USD)</span>
              <span>State</span>
            </div>
            {assetRows.map((asset) => (
              <div key={asset.key} role="row">
                <span>
                  <i>{asset.name.slice(0, 1)}</i>
                  <strong>{asset.description}</strong>
                  <small>{asset.name}</small>
                </span>
                <span>{asset.balance}</span>
                <span>{asset.value}</span>
                <b className={`wallet-change-${asset.tone}`}>{asset.change}</b>
              </div>
            ))}
          </div>
        </section>

        <section className="wallet-activity-section">
          <div className="wallet-section-title">
            <h2>Recent activity</h2>
            <button type="button" onClick={() => setActivePanel("activity")}>
              View all activity
              <ChevronRight size={16} aria-hidden="true" />
            </button>
          </div>
          <div className="wallet-activity-table" role="table" aria-label="Recent activity">
            <div role="row">
              <span>Time</span>
              <span>Type</span>
              <span>Asset</span>
              <span>To / From</span>
              <span>Amount</span>
              <span>Status</span>
            </div>
            {activityRows.slice(0, 4).map((row) => (
              <div key={row.id} role="row">
                <span>{timestampLabel()}</span>
                <span>{row.type}</span>
                <span>{row.asset}</span>
                <span>{row.route}</span>
                <span>{row.amount}</span>
                <b>{row.status}</b>
              </div>
            ))}
          </div>
        </section>
      </main>

      <aside className="wallet-app-rightbar">
        <section className="wallet-side-card wallet-account-card">
          <h2>Account</h2>
          <span>Address</span>
          <div className="wallet-copy-row">
            <strong>{primaryWalletAddress ? shortId(primaryWalletAddress, 7, 5) : "No wallet"}</strong>
            <button type="button" disabled={!primaryWalletAddress} onClick={() => void copyValue(primaryWalletAddress, "Address copied.")}>
              <Copy size={18} aria-hidden="true" />
            </button>
            <button type="button" disabled={!primaryWalletAddress} onClick={() => setActivePanel("receive")}>
              <ExternalLink size={18} aria-hidden="true" />
            </button>
          </div>
          <button type="button" onClick={() => setActivePanel("security")}>
            <ShieldCheck size={21} aria-hidden="true" />
            <strong>Security</strong>
            <small>Protected</small>
            <ChevronRight size={17} aria-hidden="true" />
          </button>
          <button type="button" onClick={() => setActivePanel("settings")}>
            <Cloud size={21} aria-hidden="true" />
            <strong>Backup</strong>
            <small>{status?.exists ? "Vault saved locally" : "Create wallet"}</small>
            <ChevronRight size={17} aria-hidden="true" />
          </button>
        </section>

        <section className="wallet-side-card">
          <div className="wallet-side-title">
            <h2>Flowchain network</h2>
            <b>{networkBadge}</b>
          </div>
          <dl className="wallet-network-facts">
            <div>
              <dt>Credits</dt>
              <dd>{bridgeStatus?.credits ?? credits.length}</dd>
            </div>
            <div>
              <dt>Applied</dt>
              <dd>{bridgeStatus?.applied ?? credits.filter((credit) => credit.status === "applied").length}</dd>
            </div>
            <div>
              <dt>Wallet API</dt>
              <dd>{shortId(walletApiUrl, 15, 4)}</dd>
            </div>
          </dl>
          <button className="wallet-text-action" type="button" onClick={() => void loadStatus()}>
            View network status
            <RefreshCw size={15} aria-hidden="true" />
          </button>
        </section>

        <section className="wallet-side-card wallet-bridge-card">
          <div>
            <Network size={24} aria-hidden="true" />
            <h2>Bridge to Flowchain</h2>
            <p>Move assets between chains</p>
          </div>
          <Link to="/bridge">
            Open bridge
            <ArrowRight size={17} aria-hidden="true" />
          </Link>
        </section>

        <section className="wallet-side-card wallet-watchlist-card">
          <div className="wallet-side-title">
            <h2>Watchlist</h2>
            <button type="button" onClick={() => setActivePanel("wallet")}>View all</button>
          </div>
          <div className="wallet-watch-row">
            <span>F</span>
            <strong>FLOW</strong>
            <small>$1.098</small>
            <b>+8.45%</b>
            <i />
          </div>
          <div className="wallet-watch-row">
            <span>E</span>
            <strong>ETH</strong>
            <small>{ethUsdRate ? formatUsd(ethUsdRate) : "$--"}</small>
            <b>+5.23%</b>
            <i />
          </div>
        </section>
      </aside>

      {activePanel !== "home" ? (
        <section className="wallet-action-panel" aria-label={`${activePanel} panel`}>
          <header>
            <div>
              <span>{activePanel}</span>
              <h2>
                {activePanel === "send" ? "Send tokens" : null}
                {activePanel === "receive" ? "Receive tokens" : null}
                {activePanel === "swap" ? "Swap assets" : null}
                {activePanel === "activity" ? "Activity" : null}
                {activePanel === "security" ? "Security" : null}
                {activePanel === "settings" || activePanel === "wallet" ? "Wallet settings" : null}
                {activePanel === "staking" ? "Staking" : null}
              </h2>
            </div>
            <button type="button" onClick={() => setActivePanel("home")}>Close</button>
          </header>

          {activePanel === "send" ? (
            <div className="wallet-panel-form">
              <label>
                <span>Recipient Flowchain account</span>
                <input value={sendTo} onChange={(event) => setSendTo(event.target.value)} placeholder="0x..." />
              </label>
              <label>
                <span>Amount</span>
                <input value={sendAmount} onChange={(event) => setSendAmount(event.target.value)} inputMode="decimal" placeholder="0.000001" />
              </label>
              <button type="button" disabled={loading} onClick={() => void submitSend()}>
                <Send size={17} aria-hidden="true" />
                {loading ? "Sending" : "Send"}
              </button>
            </div>
          ) : null}

          {activePanel === "receive" ? (
            <div className="wallet-receive-panel">
              <div className="wallet-qr-block" aria-hidden="true">
                <span />
                <span />
                <span />
              </div>
              <p>{primaryWalletAddress || "Create a wallet first."}</p>
              <button type="button" disabled={!primaryWalletAddress} onClick={() => void copyValue(primaryWalletAddress, "Receive address copied.")}>
                <Copy size={17} aria-hidden="true" />
                Copy address
              </button>
            </div>
          ) : null}

          {activePanel === "swap" ? (
            <div className="wallet-panel-form">
              <label>
                <span>From</span>
                <input value={swapAmount} onChange={(event) => setSwapAmount(event.target.value)} inputMode="decimal" placeholder="ETH amount" />
              </label>
              <div className="wallet-swap-route">
                <span>ETH</span>
                <ArrowRightLeft size={19} aria-hidden="true" />
                <span>FLOW</span>
              </div>
              <button type="button" onClick={submitSwapDraft}>
                <ArrowRightLeft size={17} aria-hidden="true" />
                Get quote
              </button>
            </div>
          ) : null}

          {activePanel === "activity" ? (
            <div className="wallet-panel-list">
              {activityRows.length === 0 ? <p>No wallet activity yet.</p> : null}
              {activityRows.map((row) => (
                <article key={row.id}>
                  <span>{row.type}</span>
                  <strong>{row.amount}</strong>
                  <small>{row.route}</small>
                  <b>{row.status}</b>
                </article>
              ))}
            </div>
          ) : null}

          {activePanel === "security" ? (
            <div className="wallet-security-grid">
              <article>
                <ShieldCheck size={22} aria-hidden="true" />
                <strong>Protected</strong>
                <span>Private material is not returned to the browser.</span>
              </article>
              <article>
                <Lock size={22} aria-hidden="true" />
                <strong>Encrypted vault</strong>
                <span>{result?.vaultPath ?? "Stored locally on this computer after creation."}</span>
              </article>
              <article>
                <BadgeCheck size={22} aria-hidden="true" />
                <strong>No-secret boundary</strong>
                <span>Passphrases and private keys are never shown in the UI.</span>
              </article>
            </div>
          ) : null}

          {activePanel === "settings" || activePanel === "wallet" ? (
            <div className="wallet-panel-form">
              <label>
                <span>Wallet label</span>
                <input value={label} onChange={(event) => setLabel(event.target.value)} />
              </label>
              <label>
                <span>Vault passphrase</span>
                <input value={passphrase} onChange={(event) => setPassphrase(event.target.value)} type="password" autoComplete="new-password" placeholder="8 characters minimum" />
              </label>
              <label className="wallet-inline-check">
                <input checked={replace} onChange={(event) => setReplace(event.target.checked)} type="checkbox" />
                Replace existing local operator wallet
              </label>
              <button type="button" disabled={!canCreate} onClick={() => void createWallet()}>
                <KeyRound size={17} aria-hidden="true" />
                {loading ? "Creating" : "Create encrypted wallet"}
              </button>
              <button type="button" onClick={() => void loadStatus()}>
                <RefreshCw size={17} aria-hidden="true" />
                Refresh wallet data
              </button>
            </div>
          ) : null}

          {activePanel === "staking" ? (
            <div className="wallet-empty-panel">
              <SlidersHorizontal size={28} aria-hidden="true" />
              <strong>Staking is parked for now.</strong>
              <span>The wallet layout includes the entry point, but staking controls are not enabled yet.</span>
            </div>
          ) : null}
        </section>
      ) : null}

      {message ? (
        <p className="wallet-toast" role="status">
          <AlertTriangle size={16} aria-hidden="true" />
          {message}
        </p>
      ) : null}
    </div>
  );
}
