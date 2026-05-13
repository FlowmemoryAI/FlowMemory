# Two-Node Meshtastic Field Test

Last updated: 2026-05-13

This plan covers issues #12 and #33 and uses the simulator outputs from `../simulator/` as dry-run packet fixtures before radio transmission.

## Objective

Validate that two FlowRouter-like nodes can exchange compact advisory control packets over Meshtastic while normal FlowMemory data remains on WiFi/Ethernet.

## Hardware

Node A:

- Certified OpenWrt router or lab LAN gateway.
- Raspberry Pi 5 or mini PC.
- NVMe/local cache candidate.
- Meshtastic sidecar in the correct regional variant.

Node B:

- Laptop, Raspberry Pi, or second FlowRouter-like node.
- Meshtastic sidecar in the same region/channel settings.

## Dry Run

Before using radios:

```powershell
python hardware/simulator/flowrouter_sim.py --seed 42 --out hardware/fixtures/flowrouter_sample_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-file hardware/fixtures/flowrouter_sample_seed42.json
```

Review the generated heartbeat, gateway discovery, receipt relay, cache status, sidecar status, dashboard feed, and failure/offline packet.

## Radio Setup

- Confirm region and frequency variant.
- Attach antennas before transmit.
- Record firmware version, modem preset, hop limit, channel name, and MQTT settings.
- Prefer private channel settings.
- Keep public MQTT disabled by default.
- Keep operator command warning packets non-executing.

## Test Sequence

1. Baseline both nodes on normal LAN/internet.
2. Send node heartbeat from Node A.
3. Send gateway discovery from Node A.
4. Send local cache status digest from Node A.
5. Send compact receipt relay from Node A.
6. Disable upstream internet for Node A.
7. Confirm local dashboard feed still reports LAN-local state.
8. Send emergency/offline signal from Node A.
9. Restore upstream internet.
10. Record reconciliation notes and operator confusion points.

## Success Criteria

- Node B receives heartbeat and gateway discovery packets.
- Digest and receipt packets fit the compact schema.
- Offline/failure packet is distinguishable from verified state.
- No heavy payload or secret crosses LoRa.
- Operators can explain local, advisory, and verified status.

## Metrics

- Packet count sent/received.
- RSSI/SNR if available.
- Hop count.
- Delay observations.
- Duplicate/lost packets.
- Node A upstream outage detection time.
- Local dashboard availability.
- Cache status before/during/after outage.
- Sidecar temperature and power notes if available.

## Stop Conditions

- Wrong region, antenna, or transmit configuration.
- Suspected harmful interference.
- Thermal or power instability.
- Secret, credential, channel key, model data, media, raw memory, or large artifact appears in a payload.
- Operator command warning starts to execute privileged behavior.
- Public MQTT exposure is discovered unexpectedly.
