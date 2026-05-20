import { Link } from "react-router-dom";
import {
  ArrowRightLeft,
  BadgeCheck,
  ClipboardCheck,
  Compass,
  KeyRound,
  ListChecks,
  Network,
  Route,
  Search,
  Server,
  ShieldAlert,
  Terminal,
  UserPlus,
  Wallet,
} from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardStatus } from "../data/types";
import type { WorkbenchRecord, WorkbenchSnapshot } from "../data/workbench";

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function text(value: unknown, fallback = "not recorded"): string {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }
  return String(value);
}

function stringList(value: unknown): string[] {
  return asArray(value).map((item) => text(item)).filter((item) => item !== "not recorded");
}

function statusFromText(value: unknown, fallback: DashboardStatus = "pending"): DashboardStatus {
  const normalized = text(value, "").toLowerCase();
  if (normalized === "passed" || normalized === "verified" || normalized === "ready" || normalized === "true") {
    return "verified";
  }
  if (normalized === "failed" || normalized === "failure") {
    return "failed";
  }
  if (normalized === "blocked" || normalized === "pending") {
    return "pending";
  }
  if (normalized === "stale") {
    return "stale";
  }
  return fallback;
}

function fact(record: WorkbenchRecord | undefined, label: string, fallback = "not recorded"): string {
  return record?.facts.find((candidate) => candidate.label === label)?.value ?? fallback;
}

function boolText(value: unknown): string {
  return value === true ? "true" : "false";
}

function commandGroup(commands: unknown, fallback: string[]): string[] {
  const parsed = stringList(commands);
  return parsed.length > 0 ? parsed : fallback;
}

export function ExternalTesterLaunchView({ workbench }: { workbench: WorkbenchSnapshot }) {
  const report = isRecord(workbench.raw.liveReadinessReport) ? workbench.raw.liveReadinessReport : null;
  const metrics = isRecord(report?.metrics) ? report.metrics : {};
  const testerLaunch = isRecord(report?.testerLaunch) ? report.testerLaunch : {};
  const connectPackNetwork = isRecord(testerLaunch.connectPackNetwork) ? testerLaunch.connectPackNetwork : {};
  const reportCommands = isRecord(report?.commands) ? report.commands : {};
  const testerCommands = isRecord(testerLaunch.commands) ? testerLaunch.commands : {};
  const liveReadinessRecords = workbench.sections.liveReadiness;
  const summaryRecord = liveReadinessRecords.find((record) => record.kind === "Public launch readiness") ?? liveReadinessRecords[0];
  const gateById = (id: string) => liveReadinessRecords.find((record) => record.id === id);
  const publicRpcGate = gateById("public-rpc-edge");
  const backupGate = gateById("state-backup");
  const bridgeGate = gateById("base8453-bridge-edge");
  const bridgeRelayerGate = gateById("base8453-bridge-relayer-queue");
  const testerPacketGate = gateById("external-tester-sharing");
  const testerGatewayGate = gateById("public-tester-write-gateway");
  const walletRecordCount = workbench.sections.walletMetadata.length + workbench.sections.accounts.length;
  const explorerRecordCount =
    workbench.sections.blocks.length + workbench.sections.transactions.length + workbench.sections.explorerRecords.length;
  const packetRoutes = stringList(testerLaunch.packetSmokeRoutes);
  const gatewayRoutes = stringList(testerLaunch.gatewayRoutes);
  const connectPackReadOnlyRoutes = stringList(testerLaunch.connectPackReadOnlyRoutes);
  const connectPackTesterWriteRoutes = stringList(testerLaunch.connectPackTesterWriteRoutes);
  const hasTesterRoute = (route: string) => packetRoutes.includes(route) || gatewayRoutes.includes(route);
  const ownerInputs = asArray(report?.ownerInputs).filter(isRecord).map((input) => ({
    name: text(input.name),
    group: text(input.group, "operator input"),
  }));
  const ownerInputGroups = ownerInputs.reduce<Map<string, string[]>>((groups, input) => {
    const names = groups.get(input.group) ?? [];
    names.push(input.name);
    groups.set(input.group, names);
    return groups;
  }, new Map());
  const relayerTimeoutSeconds = text(metrics.bridgeRelayerChildTimeoutSeconds);
  const relayerTimedOutStepCount = text(metrics.bridgeRelayerTimedOutStepCount, "0");
  const alertRuleCount = text(metrics.opsRuleCount, text(metrics.opsActiveRuleCount, "0"));
  const unmappedFindingCount = text(metrics.opsUnmappedCurrentFindingCount, "0");
  const publicRpcHeadersReady = metrics.publicRpcSecurityHeaders === true && metrics.publicRpcRenderedSecurityHeaders === true;
  const publicRpcHeaderPreflightReady =
    metrics.publicRpcSecurityHeaderPreflight === true && metrics.publicRpcRenderedSecurityHeaderPreflight === true;
  const publicRpcHeaderMetricsReady = metrics.opsPublicRpcSecurityHeaderMetricsPresent === true;

  const readinessCards: Array<{
    id: string;
    label: string;
    status: DashboardStatus;
    value: string;
    detail: string;
    command: string;
    to: string;
    Icon: typeof Wallet;
  }> = [
    {
      id: "wallets",
      label: "Wallets",
      status: walletRecordCount > 0 ? "verified" : "pending",
      value: String(walletRecordCount),
      detail: "Create, fund, send",
      command: commandGroup(testerCommands.wallet, ["npm run flowchain:wallet:live-tester:e2e"])[0],
      to: "/wallet?panel=tester",
      Icon: Wallet,
    },
    {
      id: "public-rpc",
      label: "Public RPC",
      status: publicRpcGate?.status ?? "pending",
      value: fact(publicRpcGate, "gate status", "blocked"),
      detail: "TLS edge and rate limits",
      command: fact(publicRpcGate, "next command", "npm run flowchain:public-rpc:check"),
      to: "/ops",
      Icon: Server,
    },
    {
      id: "rpc-headers",
      label: "RPC headers",
      status: publicRpcHeadersReady && publicRpcHeaderPreflightReady && publicRpcHeaderMetricsReady ? "verified" : "pending",
      value: boolText(publicRpcHeadersReady && publicRpcHeaderPreflightReady),
      detail: "HSTS, no-sniff, no-store, CSP",
      command: "npm run flowchain:public-rpc:deployment:automation",
      to: "/ops",
      Icon: ShieldAlert,
    },
    {
      id: "tester-gateway",
      label: "Tester gateway",
      status: testerGatewayGate?.status ?? statusFromText(testerLaunch.gatewayStatus),
      value: text(testerLaunch.gatewayStatus, fact(testerGatewayGate, "gate status", "blocked")),
      detail: "Bearer auth, faucet cap, send cap",
      command: commandGroup(testerCommands.gateway, ["npm run flowchain:tester:gateway:e2e"])[0],
      to: "/wallet?panel=tester",
      Icon: KeyRound,
    },
    {
      id: "packet-smoke",
      label: "Packet smoke",
      status: statusFromText(testerLaunch.packetExecutableSmokeValidated),
      value: boolText(testerLaunch.packetExecutableSmokeValidated),
      detail: "Executable packet route proof",
      command: commandGroup(testerCommands.readiness, [
        "npm run flowchain:tester:readiness -- -AllowBlocked",
        "npm run flowchain:external-tester:packet -- -AllowBlocked",
      ])[1],
      to: "/raw",
      Icon: Route,
    },
    {
      id: "connect-pack",
      label: "Connect pack",
      status: statusFromText(testerLaunch.connectPackReady),
      value: boolText(testerLaunch.connectPackReady),
      detail: text(connectPackNetwork.chainId, "network profile"),
      command: commandGroup(testerCommands.readiness, [
        "npm run flowchain:tester:readiness -- -AllowBlocked",
        "npm run flowchain:external-tester:packet -- -AllowBlocked",
      ])[1],
      to: "/raw",
      Icon: Network,
    },
    {
      id: "bridge",
      label: "Bridge",
      status: bridgeGate?.status ?? "pending",
      value: fact(bridgeGate, "gate status", "blocked"),
      detail: "Base 8453 inputs and relayer queue",
      command: fact(bridgeRelayerGate, "next command", "npm run flowchain:bridge:relayer:once -- -AllowBlocked"),
      to: "/bridge",
      Icon: ArrowRightLeft,
    },
    {
      id: "explorer",
      label: "Explorer",
      status: explorerRecordCount > 0 ? "verified" : "pending",
      value: String(explorerRecordCount),
      detail: "Blocks, transactions, receipts",
      command: "npm run flowchain:product-e2e",
      to: "/explorer",
      Icon: Compass,
    },
  ];

  const gatewayProofCommand = commandGroup(testerCommands.gateway, ["npm run flowchain:tester:gateway:e2e"])[0];
  const walletProofCommand = commandGroup(testerCommands.wallet, ["npm run flowchain:wallet:live-tester:e2e"])[0];
  const testerWorkflowSteps: Array<{
    id: string;
    label: string;
    detail: string;
    route: string;
    status: DashboardStatus;
    command: string;
    to: string;
    Icon: typeof Wallet;
    value: string;
  }> = [
    {
      id: "create",
      label: "Create tester wallet",
      detail: "Friend creates browser-safe wallet metadata through the authenticated tester gateway.",
      route: "/tester/wallets/create",
      status: hasTesterRoute("/tester/wallets/create") ? testerGatewayGate?.status ?? statusFromText(testerLaunch.gatewayStatus) : "pending",
      command: gatewayProofCommand,
      to: "/wallet?panel=tester",
      Icon: UserPlus,
      value: hasTesterRoute("/tester/wallets/create") ? "route ready" : "route missing",
    },
    {
      id: "faucet",
      label: "Faucet fund",
      detail: "Owner-capped test units fund the tester wallet without exposing secret material.",
      route: "/tester/faucet",
      status: statusFromText(testerLaunch.faucetRouteValidated),
      command: gatewayProofCommand,
      to: "/wallet?panel=tester",
      Icon: Wallet,
      value: hasTesterRoute("/tester/faucet") ? "route ready" : "route missing",
    },
    {
      id: "send",
      label: "Send capped transfer",
      detail: "Tester-to-tester sends use the bearer gateway and enforce the configured max units.",
      route: "/tester/wallets/send",
      status: hasTesterRoute("/tester/wallets/send") ? testerGatewayGate?.status ?? statusFromText(testerLaunch.gatewayStatus) : "pending",
      command: walletProofCommand,
      to: "/wallet?panel=tester",
      Icon: ArrowRightLeft,
      value: hasTesterRoute("/tester/wallets/send") ? "route ready" : "route missing",
    },
    {
      id: "inspect",
      label: "Inspect explorer",
      detail: "Blocks, faucet records, balances, and transfer rows are searchable after the send.",
      route: "/explorer",
      status: explorerRecordCount > 0 ? "verified" : "pending",
      command: "npm run flowchain:product-e2e",
      to: "/explorer",
      Icon: Search,
      value: `${explorerRecordCount} records`,
    },
  ];

  const commandGroups = [
    {
      label: "Pre-exposure",
      commands: commandGroup(reportCommands.preExposure, ["npm run flowchain:public-deployment:contract -- -AllowBlocked"]),
    },
    {
      label: "Tester packet",
      commands: commandGroup(testerCommands.readiness, [
        "npm run flowchain:tester:readiness -- -AllowBlocked",
        "npm run flowchain:external-tester:packet -- -AllowBlocked",
      ]),
    },
    {
      label: "Tester gateway",
      commands: commandGroup(testerCommands.gateway, ["npm run flowchain:tester:gateway:e2e"]),
    },
    {
      label: "Rollback",
      commands: commandGroup(reportCommands.rollback, ["npm run flowchain:public-deployment:contract -- -AllowBlocked"]),
    },
  ];

  const ownerGateStatus = (group: string): DashboardStatus => {
    if (group.includes("public RPC")) return publicRpcGate?.status ?? "pending";
    if (group.includes("backup")) return backupGate?.status ?? "pending";
    if (group.includes("tester")) return testerPacketGate?.status ?? "pending";
    if (group.includes("Base")) return bridgeGate?.status ?? "pending";
    return "pending";
  };

  return (
    <div className="view-stack tester-launch-view">
      <SectionHeader
        eyebrow="external testing"
        title="Friends-and-family launch"
        detail="Shareability, wallet funding, public RPC, bridge, explorer, and incident evidence from the latest live-readiness reports."
        action={
          <div className="workbench-header-actions">
            <Link className="button" to="/wallet?panel=tester">
              <UserPlus size={15} aria-hidden="true" />
              Tester tools
            </Link>
            <Link className="button" to="/explorer">
              <Search size={15} aria-hidden="true" />
              Explorer
            </Link>
            <Link className="button" to="/ops">
              <ShieldAlert size={15} aria-hidden="true" />
              Ops
            </Link>
          </div>
        }
      />

      <section className="tester-launch-command-panel" aria-label="Tester launch status">
        <div>
          <span>Shareable</span>
          <strong>{boolText(report?.packetShareable === true || testerLaunch.shareable === true)}</strong>
          <small>external sharing {boolText(testerLaunch.externalSharingReady)}</small>
        </div>
        <div>
          <span>Live infra</span>
          <strong>{boolText(testerLaunch.liveInfraReady)}</strong>
          <small>chain {boolText(testerLaunch.chainProducing)}</small>
        </div>
        <div>
          <span>Missing inputs</span>
          <strong>{text(testerLaunch.missingOwnerInputCount, "0")}</strong>
          <small>deployment {boolText(report?.deploymentReady === true)}</small>
        </div>
        <div>
          <span>Packet smoke</span>
          <strong>{boolText(testerLaunch.packetExecutableSmokeValidated)}</strong>
          <small>{packetRoutes.length} routes</small>
        </div>
        <div>
          <span>Connect pack</span>
          <strong>{boolText(testerLaunch.connectPackReady)}</strong>
          <small>{text(connectPackNetwork.chainId, "chain not recorded")}</small>
        </div>
        <div>
          <span>Gateway proof</span>
          <strong>{text(testerLaunch.gatewayStatus, "not recorded")}</strong>
          <small>configured {boolText(testerLaunch.gatewayConfigured)}</small>
        </div>
        <div>
          <span>RPC headers</span>
          <strong>{boolText(publicRpcHeadersReady && publicRpcHeaderPreflightReady)}</strong>
          <small>metrics {boolText(publicRpcHeaderMetricsReady)}</small>
        </div>
        <div>
          <span>Relayer timeout</span>
          <strong>{relayerTimeoutSeconds}</strong>
          <small>timed out steps {relayerTimedOutStepCount}</small>
        </div>
        <div>
          <span>Alert rules</span>
          <strong>{alertRuleCount}</strong>
          <small>unmapped findings {unmappedFindingCount}</small>
        </div>
        <div>
          <span>Tester network</span>
          <strong>{boolText(testerLaunch.testerNetworkFresh)}</strong>
          <small>rehearsal {boolText(testerLaunch.localTesterRehearsalReady)}; testers {text(testerLaunch.testerCount, "0")}</small>
        </div>
        <div>
          <span>Chain head</span>
          <strong>{text(metrics.latestHeight)}</strong>
          <small>finalized {text(metrics.finalizedHeight)}</small>
        </div>
      </section>

      <section className="tester-launch-layout">
        <div className="tester-launch-main">
          <article className="panel tester-launch-workflow">
            <div className="panel-heading">
              <div>
                <Route size={18} aria-hidden="true" />
                <h2>Tester workflow</h2>
              </div>
              <StatusBadge status={testerPacketGate?.status ?? "pending"} compact />
            </div>
            <div className="tester-launch-rail">
              {testerWorkflowSteps.map(({ id, label, detail, route, status, command, to, Icon, value }) => (
                <Link key={id} className="tester-launch-step" to={to}>
                  <span className="tester-launch-step-head">
                    <span className="tester-launch-step-icon">
                      <Icon size={17} aria-hidden="true" />
                    </span>
                    <StatusBadge status={status} compact />
                  </span>
                  <strong>{label}</strong>
                  <span>{detail}</span>
                  <code>{route}</code>
                  <code>{command}</code>
                  <b>{value}</b>
                </Link>
              ))}
            </div>
          </article>

          <article className="panel tester-launch-connect-pack">
            <div className="panel-heading">
              <div>
                <Network size={18} aria-hidden="true" />
                <h2>Connection profile</h2>
              </div>
              <StatusBadge status={statusFromText(testerLaunch.connectPackReady)} compact />
            </div>
            <div className="tester-launch-profile-grid">
              <div>
                <span>network</span>
                <strong>{text(connectPackNetwork.name, "not recorded")}</strong>
              </div>
              <div>
                <span>chain</span>
                <strong>{text(connectPackNetwork.chainId, "not recorded")}</strong>
              </div>
              <div>
                <span>RPC</span>
                <code>{text(connectPackNetwork.rpcEndpointPlaceholder, "<OWNER_PUBLIC_ENDPOINT>/rpc")}</code>
              </div>
              <div>
                <span>explorer</span>
                <code>{text(connectPackNetwork.explorerSummaryUrlPlaceholder, "<OWNER_PUBLIC_ENDPOINT>/explorer/summary")}</code>
              </div>
            </div>
            <div className="tester-launch-route-pair">
              <div>
                <strong>Read routes</strong>
                <div>
                  {connectPackReadOnlyRoutes.map((route) => (
                    <code key={`read:${route}`}>{route}</code>
                  ))}
                </div>
              </div>
              <div>
                <strong>Write routes</strong>
                <div>
                  {connectPackTesterWriteRoutes.map((route) => (
                    <code key={`write:${route}`}>{route}</code>
                  ))}
                </div>
              </div>
            </div>
          </article>

          <article className="panel tester-launch-checklist">
            <div className="panel-heading">
              <div>
                <ClipboardCheck size={18} aria-hidden="true" />
                <h2>Launch path</h2>
              </div>
              <StatusBadge status={summaryRecord?.status ?? "pending"} compact />
            </div>
            <div className="tester-launch-card-grid">
              {readinessCards.map(({ id, label, status, value, detail, command, to, Icon }) => (
                <Link key={id} className="tester-launch-card" to={to}>
                  <span className="tester-launch-card-head">
                    <span className="tester-launch-card-icon">
                      <Icon size={17} aria-hidden="true" />
                    </span>
                    <StatusBadge status={status} compact />
                  </span>
                  <strong>{label}</strong>
                  <span>{detail}</span>
                  <code>{command}</code>
                  <b>{value}</b>
                </Link>
              ))}
            </div>
          </article>

          <article className="panel tester-launch-routes">
            <div className="panel-heading">
              <div>
                <BadgeCheck size={18} aria-hidden="true" />
                <h2>Packet smoke</h2>
              </div>
              <StatusBadge status={statusFromText(testerLaunch.packetStatus)} compact />
            </div>
            {packetRoutes.length > 0 ? (
              <div className="tester-launch-route-grid">
                {packetRoutes.map((route) => (
                  <code key={route}>{route}</code>
                ))}
              </div>
            ) : (
              <EmptyState title="Packet routes missing" detail="Run npm run flowchain:external-tester:packet -- -AllowBlocked, then sync fixtures." />
            )}
            <div className="tester-launch-gateway-routes">
              <strong>Gateway write routes</strong>
              <div>
                {gatewayRoutes.map((route) => (
                  <code key={route}>{route}</code>
                ))}
              </div>
            </div>
          </article>
        </div>

        <aside className="tester-launch-side">
          <article className="panel tester-launch-owner-inputs">
            <div className="panel-heading">
              <div>
                <ListChecks size={18} aria-hidden="true" />
                <h2>Owner inputs</h2>
              </div>
              <StatusBadge status={statusFromText(metrics.ownerInputReady)} compact />
            </div>
            {[...ownerInputGroups.entries()].map(([group, names]) => (
              <details key={group} open={group === "public RPC edge" || group === "tester write gateway"}>
                <summary>
                  <span>{group}</span>
                  <StatusBadge status={ownerGateStatus(group)} compact />
                </summary>
                <div>
                  {names.map((name) => (
                    <code key={`${group}:${name}`}>{name}</code>
                  ))}
                </div>
              </details>
            ))}
          </article>

          <article className="panel tester-launch-commands">
            <div className="panel-heading">
              <div>
                <Terminal size={18} aria-hidden="true" />
                <h2>Commands</h2>
              </div>
              <StatusBadge status={statusFromText(metrics.noSecretStatus, "verified")} compact />
            </div>
            {commandGroups.map((group) => (
              <details key={group.label} open={group.label !== "Rollback"}>
                <summary>{group.label}</summary>
                <div>
                  {group.commands.map((command) => (
                    <code key={`${group.label}:${command}`}>{command}</code>
                  ))}
                </div>
              </details>
            ))}
          </article>
        </aside>
      </section>
    </div>
  );
}
