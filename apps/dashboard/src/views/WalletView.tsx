import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, Copy, KeyRound, RefreshCw, ShieldCheck, Wallet } from "lucide-react";
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

interface WalletViewProps {
  workbench: WorkbenchSnapshot;
}

type WalletApiResult<T> = {
  payload: T;
  url: string;
};

class WalletApiError extends Error {
  status?: number;
  url?: string;
}

function shortId(value: string): string {
  return value.length > 14 ? `${value.slice(0, 8)}...${value.slice(-6)}` : value;
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

export function WalletView({ workbench }: WalletViewProps) {
  const controlPlaneUrl = workbench.controlPlane.url;
  const apiCandidates = useMemo(() => walletApiCandidates(controlPlaneUrl), [controlPlaneUrl]);
  const [walletApiUrl, setWalletApiUrl] = useState(controlPlaneUrl);
  const [status, setStatus] = useState<WalletStatus | null>(null);
  const [result, setResult] = useState<WalletCreateResult | null>(null);
  const [label, setLabel] = useState("flowchain-operator");
  const [passphrase, setPassphrase] = useState("");
  const [replace, setReplace] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const activeAccount = result?.account ?? status?.account ?? null;
  const activeAccountId = accountId(activeAccount);
  const canCreate = passphrase.length >= 8 && !loading;

  const facts = useMemo(() => [
    { label: "account id", value: activeAccountId || "not created" },
    { label: "key scheme", value: safeText(activeAccount?.keyScheme, "secp256k1") },
    { label: "chain id", value: safeText(activeAccount?.chainId, "31337") },
    { label: "next nonce", value: safeText(activeAccount?.nextNonce, "0") },
    { label: "wallet api", value: walletApiUrl },
    { label: "metadata", value: safeText(result?.metadataPath ?? status?.metadataPath) },
    { label: "vault", value: safeText(result?.vaultPath) },
  ], [activeAccount, activeAccountId, result, status, walletApiUrl]);

  async function loadStatus() {
    try {
      const { payload, url } = await fetchWalletApi<WalletStatus>(apiCandidates, "/wallets/operator");
      setWalletApiUrl(url);
      setStatus(payload);
      setMessage(null);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "wallet status unavailable");
    }
  }

  useEffect(() => {
    void loadStatus();
  }, [apiCandidates]);

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
      setMessage(payload.alreadyExists ? safeText(payload.note, "Existing wallet loaded.") : "Wallet created.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "wallet creation failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className="wallet-view" aria-label="FlowChain wallet">
      <div className="section-heading wallet-heading">
        <div>
          <span className="eyebrow">local wallet</span>
          <h1>FlowChain wallet</h1>
          <p>Encrypted local vault and public FlowChain account metadata.</p>
        </div>
        <button className="button" type="button" onClick={() => void loadStatus()}>
          <RefreshCw size={16} aria-hidden="true" />
          Refresh
        </button>
      </div>

      <div className="wallet-grid">
        <article className="wallet-primary-panel">
          <div className="wallet-account-topline">
            <span className="wallet-account-icon" aria-hidden="true">
              <Wallet size={24} />
            </span>
            <div>
              <span>{status?.exists || result?.created ? "Active wallet" : "No wallet loaded"}</span>
              <strong>{activeAccountId ? shortId(activeAccountId) : "Create local wallet"}</strong>
            </div>
          </div>

          <dl className="wallet-fact-grid">
            {facts.map((fact) => (
              <div key={fact.label}>
                <dt>{fact.label}</dt>
                <dd>{fact.value}</dd>
              </div>
            ))}
          </dl>

          <div className="wallet-action-row">
            <button
              className="button button-primary"
              type="button"
              disabled={!activeAccountId}
              onClick={() => {
                void navigator.clipboard?.writeText(activeAccountId);
                setMessage("Account id copied.");
              }}
            >
              <Copy size={16} aria-hidden="true" />
              Copy account id
            </button>
            <a className="button" href="/bridge">
              Open bridge
            </a>
          </div>
        </article>

        <article className="wallet-create-panel">
          <div className="wallet-panel-title">
            <KeyRound size={20} aria-hidden="true" />
            <h2>Create wallet</h2>
          </div>

          <label className="wallet-form-field">
            <span>Label</span>
            <input value={label} onChange={(event) => setLabel(event.target.value)} />
          </label>

          <label className="wallet-form-field">
            <span>Vault passphrase</span>
            <input
              value={passphrase}
              onChange={(event) => setPassphrase(event.target.value)}
              type="password"
              autoComplete="new-password"
              placeholder="8 characters minimum"
            />
          </label>

          <label className="wallet-toggle-row">
            <input checked={replace} onChange={(event) => setReplace(event.target.checked)} type="checkbox" />
            <span>Replace existing local operator wallet</span>
          </label>

          <button className="button button-primary wallet-create-button" type="button" disabled={!canCreate} onClick={() => void createWallet()}>
            <ShieldCheck size={16} aria-hidden="true" />
            {loading ? "Creating" : "Create encrypted wallet"}
          </button>
        </article>
      </div>

      {message ? (
        <p className="wallet-message">
          <AlertTriangle size={16} aria-hidden="true" />
          {message}
        </p>
      ) : null}
    </section>
  );
}
