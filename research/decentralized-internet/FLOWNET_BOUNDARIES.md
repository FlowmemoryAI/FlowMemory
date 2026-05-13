# FlowNet Boundaries

Last updated: 2026-05-13

FlowNet is the working research name for FlowMemory's local resilience and decentralized-connectivity experiments around FlowRouter. This note defines what can be claimed in v0.

## Boundary Statement

FlowNet v0 is a local-first resilience experiment. It does not create global internet by itself. At least one gateway needs upstream internet for external sync, and normal data paths use WiFi, Ethernet, cellular, or existing ISP infrastructure.

Meshtastic and LoRa are low-bandwidth side channels for compact control messages. They do not carry normal app traffic, AI memory, model artifacts, media, or bulk files.

## In Scope

- Local LAN availability during upstream outages.
- LAN-only dashboard access.
- Bounded local/offline cache.
- Gateway availability beacons.
- Compact FlowPulse or receipt digests.
- Field diagnostics.
- Device identity and tamper-risk research.
- Enclosure, power, and thermal field notes.

## Out Of Scope

- ISP replacement.
- Global internet without upstream gateways.
- Production public mesh infrastructure.
- Passive-income relay/mining claims.
- Tokenomics.
- Full trustlessness claims.
- Custom RF boards.
- Production manufacturing.
- Final CAD without measurements.
- Emergency-service reliability claims.

## V0 Topologies

| Topology | What it can show | What it cannot claim |
| --- | --- | --- |
| Single FlowRouter on LAN | Local dashboard and cache behavior during upstream loss. | Mesh resilience or offsite sync. |
| Two FlowRouters with Meshtastic sidecars | Compact control signaling under degraded IP. | Broadband, full receipt sync, or production mesh. |
| FlowRouter plus upstream gateway | Reconnect and cache reconciliation behavior. | Independent global internet. |
| Lab mini PC plus travel router | Measurement, test automation, and routing experiments. | Final hardware product shape. |

## Trust Boundaries

- Local cache is local evidence, not final truth.
- Chain-derived receipts and indexer/verifier outputs remain the verification path.
- Radio messages are advisory unless authenticated and replay-protected.
- Physical devices are tamperable.
- Operator dashboards can mislead if they blur local, advisory, and verified state.

## Appchain Hardware Observer Boundary

For issue #37, FlowRouter-class devices may later observe appchain or L1-like activity as cache, diagnostic, and operator-visibility nodes. They are not validators, data availability providers, consensus participants, or mandatory protocol infrastructure in V0.

Allowed observer roles:

- Cache compact appchain or protocol digests.
- Relay short receipt or verifier-report references over low-bandwidth side channels.
- Show local/advisory/verified state to operators.
- Record field diagnostics that help reconcile state after normal network paths return.

Not allowed in V0:

- Validator hardware requirements.
- Validator rewards or hardware economics.
- Data availability duties.
- Consensus duties.
- Production L1 or appchain operation.

## Claims Allowed In V0

- "Keeps a local dashboard reachable on LAN during upstream outage" if measured.
- "Sends compact advisory status over Meshtastic" if measured.
- "Caches selected compact receipts/digests locally" if measured.
- "Uses certified commodity router/radio hardware" when true for the chosen parts.

## Claims Not Allowed In V0

- "Decentralized internet replacement."
- "No ISP needed."
- "Earn passive income."
- "Trustless hardware proof."
- "Production mesh."
- "Unlimited offline AI memory."
- "LoRa carries FlowMemory data."

## Metrics To Collect

- Upstream outage detection time.
- LAN dashboard availability.
- Cache write/read and power-loss behavior.
- Reconnect reconciliation notes.
- Meshtastic delivery count, RSSI, SNR, hop count, and retry behavior.
- Device temperature and power draw.
- Operator confusion points.
- Tamper observations.

## Follow-Up Decision Needs

- Whether FlowRouter needs a formal device identity scheme.
- Whether FlowNet should define public gateway rules.
- Whether local dashboard state needs a strict local/advisory/verified taxonomy.
- Whether Memory Cartridges are NFC-only in v0 or include removable storage later.
