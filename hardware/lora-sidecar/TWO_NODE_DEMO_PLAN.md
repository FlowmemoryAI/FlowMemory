# Two-Node FlowRouter Meshtastic Demo Plan

Last updated: 2026-05-13

This document supports issue #33. It defines a controlled two-node demo for compact control signaling without implementing firmware, app UI, production deployment, or public mesh infrastructure.

## Demo Objective

Show that two FlowRouter-like nodes can exchange compact advisory status over Meshtastic/LoRa when normal IP connectivity is degraded.

The demo must not claim ISP replacement, production mesh, emergency reliability, passive income, or high-bandwidth LoRa transport.

## Topology

| Node | Hardware shape | Role |
| --- | --- | --- |
| Node A | Router plus local compute plus Meshtastic sidecar | Simulated gateway with upstream internet toggled on/off. |
| Node B | Router or laptop plus Meshtastic sidecar | Observer node that receives advisory control messages. |

At least one node needs upstream internet for external sync tests. During outage simulation, local dashboard and cache behavior should remain LAN-local.

## Allowed Message Candidates

Use only messages from `CONTROL_MESSAGE_INVENTORY.md`:

- Node heartbeat.
- Gateway availability.
- FlowPulse digest.
- Artifact availability digest.
- Compact receipt reference.
- Field diagnostic.
- Emergency/local signal.
- Operator command warning as non-executing intent only.

## Setup Checklist

- Confirm test region and set Meshtastic LoRa region before transmit.
- Confirm antennas are attached.
- Record firmware version, modem preset, hop limit, channel name, and MQTT state.
- Prefer a private channel for the test.
- Keep public MQTT disabled unless the test explicitly documents a private broker and uplink/downlink posture.
- Keep operator command warnings disabled or non-executing.
- Prepare local logs for router, compute, cache, and sidecar observations.

## Demo Steps

1. Baseline both nodes with upstream internet available.
2. Send heartbeat and gateway availability messages.
3. Record RSSI, SNR, hop count, loss, and delay observations.
4. Disable upstream internet on Node A.
5. Confirm Node A local dashboard remains reachable on LAN.
6. Send local-only gateway availability and field diagnostic messages.
7. Send one compact digest or receipt reference using test data only.
8. Restore upstream internet.
9. Record reconciliation notes and whether advisory state was clearly distinguishable from verified state.

## Success Metrics

- Node B receives at least one heartbeat and one gateway availability update from Node A.
- Node A display or local log distinguishes online, local-only, and degraded state.
- No message exceeds the compact inventory shape.
- No artifact, AI memory, media, credential, or secret is transmitted over LoRa.
- Operators can explain which state is local, advisory, or verified.

## Stop Conditions

- Suspected regulatory or interference issue.
- Wrong region or antenna configuration.
- Device overheats or power becomes unstable.
- Public MQTT exposure is discovered unexpectedly.
- Any secret or sensitive payload appears in a control message.
- Operator command warning starts to behave like an executable command.

## Risks To Record

- Device identity spoofing.
- Replayed LoRa messages.
- Packet loss and duplicate delivery.
- Channel-key leakage.
- MQTT exposure.
- Bandwidth overclaim.
- Regulatory mistakes.
- Operator confusion.
- Cache state being mistaken for verified state.

## Outputs

- Field notes under `hardware/lora-sidecar/` or `hardware/flowrouter/`.
- Updated message inventory if a payload shape is too large or ambiguous.
- Updated security assumptions if authentication, replay, or operator-key risks change.
