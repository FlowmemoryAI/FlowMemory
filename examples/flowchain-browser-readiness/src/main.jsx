import React, { useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { CheckCircle2, Loader2, LockKeyhole, RadioTower, RefreshCw, ShieldAlert } from "lucide-react";

import {
  checkFlowChainBrowserReadiness,
  redactFlowChainBrowserText,
} from "../browser-readiness.js";

import "./styles.css";

const DEFAULT_ORIGIN = import.meta.env.VITE_FLOWCHAIN_RPC_ORIGIN ?? "http://127.0.0.1:8787";

function JsonPanel({ result, error, isLoading }) {
  const content = useMemo(() => {
    if (isLoading) {
      return JSON.stringify({
        schema: "flowchain.example.browser_readiness_pending.v1",
        status: "checking",
        noSecrets: true,
      }, null, 2);
    }
    if (error !== null) {
      return JSON.stringify({
        schema: "flowchain.example.browser_readiness_error.v1",
        message: redactFlowChainBrowserText(error),
        noSecrets: true,
      }, null, 2);
    }
    if (result !== null) return JSON.stringify(result, null, 2);
    return JSON.stringify({
      schema: "flowchain.example.browser_readiness_idle.v1",
      status: "idle",
      checkedEndpoints: ["/rpc/discover", "/rpc/readiness"],
      noSecrets: true,
    }, null, 2);
  }, [error, isLoading, result]);

  return <pre aria-live="polite">{content}</pre>;
}

function Metric({ label, value, tone = "neutral" }) {
  return (
    <div className={`metric metric-${tone}`}>
      <span>{label}</span>
      <strong title={String(value)}>{value}</strong>
    </div>
  );
}

function StatusHeader({ result, error, isLoading }) {
  if (isLoading) {
    return (
      <div className="status-line status-pending">
        <Loader2 aria-hidden="true" className="spin" size={18} />
        Checking public-safe endpoints
      </div>
    );
  }

  if (error !== null) {
    return (
      <div className="status-line status-error">
        <ShieldAlert aria-hidden="true" size={18} />
        Readiness check failed
      </div>
    );
  }

  if (result?.safeToSharePublicly) {
    return (
      <div className="status-line status-ready">
        <CheckCircle2 aria-hidden="true" size={18} />
        Shareable public RPC
      </div>
    );
  }

  return (
    <div className="status-line status-blocked">
      <LockKeyhole aria-hidden="true" size={18} />
      Local only until live gates pass
    </div>
  );
}

function FlowChainReadinessApp() {
  const [origin, setOrigin] = useState(DEFAULT_ORIGIN);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setIsLoading(true);
    setError(null);
    try {
      const summary = await checkFlowChainBrowserReadiness({ origin });
      setResult(summary);
    } catch (checkError) {
      setResult(null);
      setError(checkError instanceof Error ? checkError.message : String(checkError));
    } finally {
      setIsLoading(false);
    }
  }

  const blockers = result?.missingProductionEnvNames ?? [];
  const shareable = result?.safeToSharePublicly === true;
  const methodCount = result?.methodCount ?? 0;
  const publicReadyMethodCount = result?.publicReadyMethodCount ?? 0;

  return (
    <main className="shell">
      <section className="intro" aria-labelledby="title">
        <div className="intro-kicker">
          <RadioTower aria-hidden="true" size={18} />
          External starter
        </div>
        <h1 id="title">FlowChain browser readiness</h1>
        <p>
          Connects to discovery and readiness only, then keeps the shareable state locked until the public RPC and production gates agree.
        </p>
        <div className="endpoint-list" aria-label="Read-only endpoints">
          <code>GET /rpc/discover</code>
          <code>GET /rpc/readiness</code>
        </div>
      </section>

      <section className="workbench" aria-label="Readiness workbench">
        <form className="origin-form" onSubmit={handleSubmit}>
          <label htmlFor="origin">
            RPC origin
            <span>Use an origin only, without a path or token.</span>
          </label>
          <div className="input-row">
            <input
              id="origin"
              name="origin"
              value={origin}
              onChange={(event) => setOrigin(event.target.value)}
              autoComplete="off"
              spellCheck="false"
            />
            <button type="submit" disabled={isLoading}>
              {isLoading ? <Loader2 aria-hidden="true" className="spin" size={17} /> : <RefreshCw aria-hidden="true" size={17} />}
              Check
            </button>
          </div>
          {error !== null ? <p className="form-error">{redactFlowChainBrowserText(error)}</p> : null}
        </form>

        <div className="result-area">
          <StatusHeader result={result} error={error} isLoading={isLoading} />
          <div className="metrics" aria-label="Readiness metrics">
            <Metric label="Boundary" value={shareable ? "Shareable" : "Locked"} tone={shareable ? "ready" : "blocked"} />
            <Metric label="Methods" value={methodCount} />
            <Metric label="Public" value={publicReadyMethodCount} tone={publicReadyMethodCount > 0 ? "ready" : "neutral"} />
          </div>
          <div className="blockers">
            <span>Blocking inputs</span>
            <strong title={blockers.join(", ") || "none"}>{blockers.length > 0 ? blockers.join(", ") : "none"}</strong>
          </div>
          <JsonPanel result={result} error={error} isLoading={isLoading} />
        </div>
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <FlowChainReadinessApp />
  </React.StrictMode>,
);
