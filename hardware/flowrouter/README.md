# FlowRouter Hardware Foundation

Last updated: 2026-05-13

FlowRouter is the FlowMemory hardware gateway track. V0 is production-shaped but research-safe: it should look like the beginning of a real device family while remaining built from certified commodity hardware, measured prototypes, and explicit non-goals.

## Product Thesis

FlowRouter may combine:

- Certified OpenWrt router for normal WiFi/Ethernet data paths.
- Raspberry Pi 5 or x86_64 mini PC for local services, telemetry, and cache control.
- NVMe artifact cache for bounded offline storage.
- Meshtastic/LoRa sidecar for low-bandwidth control signaling.
- E-paper or OLED display for local status.
- Blue FlowCore LED light pipe for at-a-glance state.
- NFC memory cartridge slot for physical memory identity, pointers, or removable cache workflows.
- Local dashboard reachable on the LAN.

FlowRouter does not create global internet by itself. At least one gateway needs upstream internet for external sync. Meshtastic and LoRa are control signaling only; WiFi and Ethernet carry normal data.

## V0 Boundary

V0 uses certified router/radio hardware and off-the-shelf compute. It does not include custom RF boards, custom antennas, final CAD, production firmware, production mesh infrastructure, tokenomics, passive-income claims, ISP replacement claims, or full trustlessness claims.

## Hardware Tiers

| Tier | V0 meaning | Research boundary |
| --- | --- | --- |
| FlowRouter Dev Kit | Bench and early field gateway using commodity router, Pi/mini PC, sidecar, display, and open enclosure notes. | Primary v0 build target. Not a sellable SKU. |
| FlowRouter Pro | Higher-capacity gateway with stronger compute, better thermal envelope, NVMe, and multi-WAN experiments. | Research profile only; no production commitment. |
| FlowMemory Beacon | Small status node with display, FlowCore LED, and Meshtastic signaling. | Control/status node, not a router or artifact cache. |
| FlowMemory Vault | Local artifact/cache node with larger NVMe and tamper observations. | Cache research only; not a permanent source of truth. |
| FlowMemory Forge | Lab node for printing, measurement, field-test preparation, and device provisioning. | Lab fixture, not field deployment infrastructure. |
| FlowMemory Atlas | Mapping/observability profile for field-test topology and node health. | Documentation and telemetry concept only. |
| Memory Cartridges | Physical NFC-tagged cartridges for memory pointers, labels, and possibly removable cache media. | V0 uses pointers and test fixtures, not secret-bearing production media. |

## Directory Map

- `FLOWROUTER_V0_SCOPE.md`: scope, non-goals, hardware assumptions, and tier definitions.
- `FLOWCHAIN_LOCAL_ALPHA_SIGNALS.md`: FlowRouter packet mapping into local-alpha FlowChain operator-signal objects.
- `BOM.md`: research BOM candidates and tier summaries.
- `ASSEMBLY.md`: safe prototype assembly sequence.
- `PRINTING_GUIDE.md`: enclosure and material constraints before CAD.
- `MEASUREMENT_CHECKLIST.md`: measurements required before final CAD.
- `ENCLOSURE_CONCEPT_V0.md`: enclosure concept boundaries before final CAD.
- `FLOWCORE_LIGHT_PIPE.md`: blue FlowCore LED/light-pipe prototype notes.
- `../lora-sidecar/`: Meshtastic/LoRa sidecar role and message inventory.
- `../memory-cartridges/`: NFC memory cartridge assumptions.
- `../../research/meshtastic/`: Meshtastic role and research assumptions.
- `../../research/decentralized-internet/`: FlowNet boundary notes.
- `../simulator/`: deterministic POC packet simulator and schemas.
- `../fixtures/`: generated sample packet feeds.
- `../field-tests/`: controlled field-test plans.

## V0 Success Criteria

- A local operator can tell whether the node has upstream internet, LAN availability, cache health, power/thermal status, and sidecar status.
- A second node can receive compact Meshtastic status or digest messages during degraded IP connectivity.
- Cached state is clearly marked local-only until verified through normal network, indexer, or chain-derived paths.
- Hardware packets can be projected into local-alpha `hardwareSignals`, `operatorMetadata`, `hardwareNodes`, `workReceipts`, `verifierReports`, `bridgeAlerts`, `alerts`, `challenges`, `artifactCommitments`, and `memoryCells` without blocking the main local chain flow.
- The prototype can be measured for thermal, power, serviceability, and enclosure-fit constraints.
- The docs make it difficult to overclaim bandwidth, production readiness, trustlessness, or regulatory status.
