import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { ArrowRightLeft, Boxes, CircleDollarSign, HardDrive, KeyRound, ListFilter, Search, Server, ShieldCheck, WalletCards } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardData, DashboardStatus, Provenance } from "../data/types";
import type { WorkbenchRecord, WorkbenchSectionKey, WorkbenchSnapshot } from "../data/workbench";

type ExplorerCategory = "all" | "blocks" | "transactions" | "wallets" | "faucet" | "bridge" | "records";

type ExplorerRow = {
  id: string;
  category: Exclude<ExplorerCategory, "all">;
  title: string;
  summary: string;
  status: DashboardStatus;
  primaryRef: string;
  secondaryRef: string;
  blockNumber: number | null;
  amount: string;
  updatedAt: string;
  facts: Array<{ label: string; value: string }>;
  provenance: Provenance;
};

const CATEGORY_OPTIONS: Array<{ id: ExplorerCategory; label: string }> = [
  { id: "all", label: "All" },
  { id: "blocks", label: "Blocks" },
  { id: "transactions", label: "Transactions" },
  { id: "wallets", label: "Wallets" },
  { id: "faucet", label: "Faucet" },
  { id: "bridge", label: "Bridge" },
  { id: "records", label: "Records" },
];

const WORKBENCH_EXPLORER_SECTIONS: Array<{ key: WorkbenchSectionKey; category: ExplorerRow["category"] }> = [
  { key: "transactions", category: "transactions" },
  { key: "explorerRecords", category: "records" },
  { key: "liveReadiness", category: "records" },
  { key: "walletMetadata", category: "wallets" },
  { key: "balances", category: "wallets" },
  { key: "faucetEvents", category: "faucet" },
  { key: "realValuePilot", category: "bridge" },
  { key: "bridgeDeposits", category: "bridge" },
  { key: "bridgeCredits", category: "bridge" },
  { key: "bridgeWithdrawals", category: "bridge" },
];

function factValue(record: WorkbenchRecord | undefined, labels: string[], fallback = ""): string {
  if (!record) {
    return fallback;
  }

  for (const label of labels) {
    const fact = record.facts.find((candidate) => candidate.label.toLowerCase() === label.toLowerCase());
    if (fact?.value) {
      return fact.value;
    }
  }
  return fallback;
}

function parseBlockNumber(value: string): number | null {
  if (!/^\d+$/.test(value)) {
    return null;
  }
  return Number(value);
}

function workbenchRecordToRow(record: WorkbenchRecord, category: ExplorerRow["category"]): ExplorerRow {
  const blockNumber = parseBlockNumber(factValue(record, ["block", "block number"]));
  const primaryRef = factValue(record, ["tx", "tx hash", "transaction", "hash", "account", "wallet", "deposit", "credit"], record.id);
  const secondaryRef = factValue(record, ["from", "to", "recipient", "asset", "source"], record.kind);
  const amount = factValue(record, ["amount", "balance", "credited", "delta"], "");

  return {
    id: `${category}:${record.id}`,
    category,
    title: record.title,
    summary: record.summary,
    status: record.status,
    primaryRef,
    secondaryRef,
    blockNumber,
    amount,
    updatedAt: record.provenance.capturedAt ?? "",
    facts: record.facts.slice(0, 4),
    provenance: record.provenance,
  };
}

function buildExplorerRows(data: DashboardData, workbench: WorkbenchSnapshot): ExplorerRow[] {
  const blockRows: ExplorerRow[] = data.devnetBlocks.map((block) => ({
    id: `blocks:${block.blockHash}`,
    category: "blocks",
    title: `Block ${block.blockNumber}`,
    summary: `${block.observationCount} observations, ${block.reportCount} reports, finality distance ${block.finalityDistance}`,
    status: block.status,
    primaryRef: block.blockHash,
    secondaryRef: block.parentHash,
    blockNumber: block.blockNumber,
    amount: "",
    updatedAt: block.lastUpdated ?? block.timestamp,
    facts: [
      { label: "state root", value: block.stateRoot },
      { label: "receipt root", value: block.receiptsRoot },
      { label: "reports", value: String(block.reportCount) },
      { label: "distance", value: String(block.finalityDistance) },
    ],
    provenance: block.provenance,
  }));

  const workbenchRows = WORKBENCH_EXPLORER_SECTIONS.flatMap(({ key, category }) =>
    workbench.sections[key].map((record) => workbenchRecordToRow(record, category)),
  );

  return [...blockRows, ...workbenchRows].sort((left, right) => {
    const rightBlock = right.blockNumber ?? -1;
    const leftBlock = left.blockNumber ?? -1;
    if (rightBlock !== leftBlock) {
      return rightBlock - leftBlock;
    }
    return right.updatedAt.localeCompare(left.updatedAt);
  });
}

function rowMatches(row: ExplorerRow, query: string): boolean {
  if (!query) {
    return true;
  }
  return JSON.stringify(row).toLowerCase().includes(query);
}

function categoryCount(rows: ExplorerRow[], category: ExplorerCategory): number {
  return category === "all" ? rows.length : rows.filter((row) => row.category === category).length;
}

function traceStatus(row: ExplorerRow | undefined): DashboardStatus {
  return row?.status ?? "pending";
}

export function ExplorerView({ data, workbench }: { data: DashboardData; workbench: WorkbenchSnapshot }) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<ExplorerCategory>("all");
  const rows = useMemo(() => buildExplorerRows(data, workbench), [data, workbench]);
  const normalizedQuery = query.trim().toLowerCase();
  const filteredRows = rows.filter((row) => (category === "all" || row.category === category) && rowMatches(row, normalizedQuery));
  const latestBlock = rows.find((row) => row.category === "blocks")?.blockNumber ?? data.chain.currentBlock;
  const transactionCount = rows.filter((row) => row.category === "transactions").length;
  const walletCount = rows.filter((row) => row.category === "wallets").length;
  const fundingCount = rows.filter((row) => row.category === "faucet" || row.category === "bridge").length;
  const faucetCount = rows.filter((row) => row.category === "faucet").length;
  const recentWallet = rows.find((row) => row.category === "wallets");
  const recentFunding = rows.find((row) => row.category === "faucet" || row.category === "bridge");
  const recentTransfer = rows.find((row) => row.category === "transactions");
  const liveReadinessRecords = workbench.sections.liveReadiness;
  const liveReadinessSummary = liveReadinessRecords.find((record) => record.kind === "Public launch readiness") ?? liveReadinessRecords[0];
  const liveReadinessGates = liveReadinessRecords.filter((record) => record.kind === "Launch gate");
  const publicRpcGate = liveReadinessGates.find((record) => record.id === "public-rpc-edge");
  const backupGate = liveReadinessGates.find((record) => record.id === "state-backup") ?? liveReadinessGates.find((record) => record.id === "state-backup-owner-path-dry-run");
  const bridgeRelayerGate = liveReadinessGates.find((record) => record.id === "base8453-bridge-relayer-queue");
  const testerPacketGate = liveReadinessGates.find((record) => record.id === "external-tester-sharing");
  const launchReady = factValue(liveReadinessSummary, ["deployment ready"], "false");
  const packetShareable = factValue(liveReadinessSummary, ["packet shareable"], "false");
  const relayerChildTimeout = factValue(liveReadinessSummary, ["relayer child timeout"], "not recorded");
  const relayerTimedOutSteps = factValue(liveReadinessSummary, ["relayer timed out steps"], "0");
  const alertRules = factValue(liveReadinessSummary, ["alert rules"], "0");
  const unmappedFindings = factValue(liveReadinessSummary, ["unmapped findings"], "0");
  const sourceStatus: DashboardStatus = workbench.source === "control-plane" ? "verified" : "stale";
  const testerTraceSteps: Array<{
    id: string;
    label: string;
    detail: string;
    value: string;
    status: DashboardStatus;
    targetCategory: ExplorerCategory;
    Icon: typeof WalletCards;
  }> = [
    {
      id: "wallet",
      label: "Wallet",
      detail: recentWallet?.title ?? "Create tester wallet",
      value: recentWallet?.primaryRef ?? `${walletCount} records`,
      status: traceStatus(recentWallet),
      targetCategory: "wallets",
      Icon: WalletCards,
    },
    {
      id: "fund",
      label: "Fund",
      detail: recentFunding?.title ?? "Faucet or bridge credit",
      value: recentFunding?.amount || recentFunding?.primaryRef || `${fundingCount} proofs`,
      status: traceStatus(recentFunding),
      targetCategory: faucetCount > 0 ? "faucet" : "bridge",
      Icon: CircleDollarSign,
    },
    {
      id: "send",
      label: "Send",
      detail: recentTransfer?.title ?? "Wallet transfer",
      value: recentTransfer?.primaryRef ?? `${transactionCount} tx`,
      status: traceStatus(recentTransfer),
      targetCategory: "transactions",
      Icon: ArrowRightLeft,
    },
    {
      id: "inspect",
      label: "Inspect",
      detail: "Explorer records",
      value: `${rows.length} rows`,
      status: rows.length > 0 ? "observed" : "pending",
      targetCategory: "all",
      Icon: Search,
    },
  ];
  const launchBoundaryItems: Array<{
    id: string;
    label: string;
    detail: string;
    value: string;
    status: DashboardStatus;
    targetCategory: ExplorerCategory;
    Icon: typeof WalletCards;
  }> = [
    {
      id: "private-chain",
      label: "Private chain",
      detail: workbench.source === "control-plane" ? "Local control-plane connected" : "Fixture fallback active",
      value: `height ${latestBlock}`,
      status: sourceStatus,
      targetCategory: "blocks",
      Icon: ShieldCheck,
    },
    {
      id: "public-rpc",
      label: "Public RPC",
      detail: publicRpcGate?.title ?? "Public RPC gate not loaded",
      value: factValue(publicRpcGate, ["gate status"], publicRpcGate?.status ?? "pending"),
      status: publicRpcGate?.status ?? "pending",
      targetCategory: "records",
      Icon: Server,
    },
    {
      id: "backup",
      label: "Backup",
      detail: backupGate?.title ?? "State backup gate not loaded",
      value: factValue(backupGate, ["gate status"], backupGate?.status ?? "pending"),
      status: backupGate?.status ?? "pending",
      targetCategory: "records",
      Icon: HardDrive,
    },
    {
      id: "tester-sharing",
      label: "Tester sharing",
      detail: testerPacketGate?.title ?? "Tester packet gate not loaded",
      value: `packet ${packetShareable}`,
      status: testerPacketGate?.status ?? "pending",
      targetCategory: "records",
      Icon: KeyRound,
    },
    {
      id: "bridge-relayer",
      label: "Bridge relayer",
      detail: bridgeRelayerGate?.title ?? "Bridge relayer gate not loaded",
      value: relayerChildTimeout === "not recorded" ? factValue(bridgeRelayerGate, ["gate status"], bridgeRelayerGate?.status ?? "pending") : `timeout ${relayerChildTimeout}s`,
      status: bridgeRelayerGate?.status ?? "pending",
      targetCategory: "bridge",
      Icon: ArrowRightLeft,
    },
    {
      id: "alert-coverage",
      label: "Alert coverage",
      detail: `relayer timed out steps ${relayerTimedOutSteps}`,
      value: `${alertRules} rules; unmapped ${unmappedFindings}`,
      status: unmappedFindings === "0" ? "verified" : "pending",
      targetCategory: "records",
      Icon: ShieldCheck,
    },
  ];

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="explorer"
        title="Flowchain explorer"
        detail="Search blocks, transactions, wallet records, faucet events, and bridge evidence from the running local chain and generated readiness fixtures."
        action={
          <div className="workbench-header-actions">
            <label className="search-box">
              <Search size={16} aria-hidden="true" />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search tx, wallet, block, credit" />
            </label>
            <label className="explorer-filter">
              <ListFilter size={16} aria-hidden="true" />
              <select value={category} onChange={(event) => setCategory(event.target.value as ExplorerCategory)} aria-label="Explorer record category">
                {CATEGORY_OPTIONS.map((option) => (
                  <option key={option.id} value={option.id}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>
          </div>
        }
      />

      <section className="explorer-command-panel" aria-label="Explorer status">
        <div>
          <span>Chain head</span>
          <strong>{latestBlock}</strong>
          <small>{workbench.source === "control-plane" ? "local API" : "fixture fallback"}</small>
        </div>
        <div>
          <span>Transactions</span>
          <strong>{transactionCount}</strong>
          <small>runtime-backed records</small>
        </div>
        <div>
          <span>Wallet records</span>
          <strong>{walletCount}</strong>
          <small>public metadata only</small>
        </div>
        <div>
          <span>Funding proofs</span>
          <strong>{fundingCount}</strong>
          <small>faucet and bridge</small>
        </div>
      </section>

      <section className="explorer-settlement-trace" aria-label="Tester settlement trace">
        <div className="explorer-trace-head">
          <span>Tester trace</span>
          <strong>Create, fund, send, inspect</strong>
          <small>Each step filters the explorer to the records a tester needs after using the wallet panel.</small>
        </div>
        <div className="explorer-trace-steps">
          {testerTraceSteps.map(({ Icon, id, label, detail, status, targetCategory, value }) => (
            <button
              key={id}
              type="button"
              className={category === targetCategory ? "active" : ""}
              aria-pressed={category === targetCategory}
              onClick={() => setCategory(targetCategory)}
            >
              <span className="explorer-trace-icon" aria-hidden="true">
                <Icon size={16} />
              </span>
              <span className="explorer-trace-copy">
                <strong>{label}</strong>
                <small>{detail}</small>
              </span>
              <code>{value.startsWith("0x") ? <HashValue value={value} trim="short" /> : value}</code>
              <StatusBadge status={status} compact />
            </button>
          ))}
        </div>
      </section>

      <section className="explorer-launch-boundary" aria-label="Public launch boundary">
        <div className="explorer-launch-summary">
          <span>Launch boundary</span>
          <strong>{launchReady === "true" ? "Public launch ready" : "Private chain live"}</strong>
          <small>{liveReadinessSummary?.summary ?? "Launch readiness evidence is not loaded yet."}</small>
        </div>
        <div className="explorer-launch-grid">
          {launchBoundaryItems.map(({ Icon, detail, id, label, status, targetCategory, value }) => (
            <button
              key={id}
              type="button"
              className={category === targetCategory ? "active" : ""}
              aria-pressed={category === targetCategory}
              onClick={() => setCategory(targetCategory)}
            >
              <span className="explorer-launch-top">
                <span className="explorer-launch-icon" aria-hidden="true">
                  <Icon size={16} />
                </span>
                <StatusBadge status={status} compact />
              </span>
              <strong>{label}</strong>
              <span>{detail}</span>
              <code>{value}</code>
            </button>
          ))}
        </div>
      </section>

      <section className="explorer-category-strip" aria-label="Explorer categories">
        {CATEGORY_OPTIONS.map((option) => (
          <button key={option.id} className={category === option.id ? "active" : ""} type="button" onClick={() => setCategory(option.id)}>
            <span>{option.label}</span>
            <strong>{categoryCount(rows, option.id)}</strong>
          </button>
        ))}
      </section>

      <section className="explorer-layout">
        <div className="explorer-stream" aria-label="Explorer records">
          {filteredRows.length > 0 ? (
            filteredRows.slice(0, 80).map((row, index) => (
              <article key={`${row.id}:${index}`} className={`explorer-row explorer-row-${row.category}`}>
                <div className="explorer-row-icon" aria-hidden="true">
                  {row.category === "blocks" ? <Boxes size={18} /> : null}
                  {row.category === "transactions" || row.category === "records" ? <ArrowRightLeft size={18} /> : null}
                  {row.category === "wallets" ? <WalletCards size={18} /> : null}
                  {row.category === "faucet" || row.category === "bridge" ? <CircleDollarSign size={18} /> : null}
                </div>
                <div className="explorer-row-main">
                  <div className="explorer-row-title">
                    <span>{row.category}</span>
                    <h2>{row.title}</h2>
                    <StatusBadge status={row.status} compact />
                  </div>
                  <p>{row.summary}</p>
                  <dl className="explorer-facts">
                    <div>
                      <dt>primary</dt>
                      <dd>{row.primaryRef.startsWith("0x") ? <HashValue value={row.primaryRef} trim="short" /> : row.primaryRef}</dd>
                    </div>
                    <div>
                      <dt>secondary</dt>
                      <dd>{row.secondaryRef.startsWith("0x") ? <HashValue value={row.secondaryRef} trim="short" /> : row.secondaryRef}</dd>
                    </div>
                    <div>
                      <dt>block</dt>
                      <dd>{row.blockNumber ?? "not indexed"}</dd>
                    </div>
                    <div>
                      <dt>amount</dt>
                      <dd>{row.amount || "n/a"}</dd>
                    </div>
                  </dl>
                  <ProvenanceLine provenance={row.provenance} lastUpdated={row.updatedAt} />
                </div>
              </article>
            ))
          ) : (
            <EmptyState title="No explorer records match" detail="Adjust the search or category filter to inspect local chain activity." />
          )}
        </div>

        <aside className="explorer-side-panel" aria-label="Explorer actions">
          <div>
            <span>Tester path</span>
            <strong>Create, fund, send, inspect</strong>
            <small>Use the wallet tester panel, then return here to inspect records.</small>
            <Link to="/wallet?panel=tester">Open tester tools</Link>
          </div>
          <div>
            <span>Launch gates</span>
            <strong>{liveReadinessSummary?.title ?? "Public launch status"}</strong>
            <small>Public RPC, backup, bridge relayer, and tester sharing evidence.</small>
            <Link to="/">Open readiness</Link>
          </div>
          <div>
            <span>Bridge path</span>
            <strong>Base to Flowchain</strong>
            <small>Bridge pilot records remain blocked until owner Base inputs are configured.</small>
            <Link to="/bridge">Open bridge</Link>
          </div>
          <div>
            <span>Raw evidence</span>
            <strong>{rows.length} indexed rows</strong>
            <small>Open the raw inspector for the source reports behind this view.</small>
            <Link to="/raw">Open raw JSON</Link>
          </div>
        </aside>
      </section>
    </div>
  );
}
