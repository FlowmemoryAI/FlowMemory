# Meshtastic Role In FlowRouter v0

Last updated: 2026-05-13

Meshtastic is a FlowRouter v0 sidecar for low-bandwidth control signaling. It is not a replacement for WiFi, Ethernet, cellular, ISP service, or normal internet access.

## Role Summary

Meshtastic may support:

- Node heartbeat.
- Gateway availability status.
- Compact FlowPulse digest announcements.
- Artifact availability digests.
- Compact receipt references.
- Field diagnostics.
- Emergency/local operator attention signals.

Meshtastic must not carry:

- Heavy AI memory.
- Model artifacts.
- Media.
- Bulk app data.
- Full receipts or logs.
- Secrets.
- Production command traffic.

## Network Model

- WiFi/Ethernet carries normal FlowMemory data.
- At least one gateway needs upstream internet for external sync.
- Meshtastic may keep nearby operators informed when IP paths are degraded.
- Meshtastic may help correlate local logs after reconnect.
- Meshtastic messages are advisory until verified by authenticated local policy and normal verification paths.

## Configuration Assumptions

- Set the correct LoRa region before transmit.
- Devices in the same mesh need compatible region and modem settings.
- Keep hop count conservative.
- Keep messages small and infrequent.
- Use private channels for field tests when possible.
- Treat channel keys as test secrets that must not be committed.
- Avoid public MQTT by default.
- If MQTT is used, prefer a private broker and explicitly document uplink/downlink settings.

## Privacy And Security

Meshtastic payload encryption does not hide all metadata. V0 should assume:

- Node IDs and routing metadata may be visible.
- Channel keys can leak.
- Packets can be replayed.
- Sender identity can be spoofed without additional authentication.
- Messages can be delayed, lost, duplicated, or reordered.
- Public MQTT can expand the exposure of packets and metadata.

## Research Questions

1. What is the minimum useful status interval before channel congestion becomes a problem?
2. Which control messages remain useful when only one or two messages are delivered?
3. How should FlowRouter present "radio advisory" state versus verified state?
4. What authentication scheme fits the payload budget without creating dangerous false confidence?
5. What field metrics are needed to compare RSSI/SNR, distance, antenna placement, and enclosure effects?
6. How should public MQTT be avoided or safely isolated in lab tests?

## Link To Hardware Inventory

The candidate message inventory lives in `../../hardware/lora-sidecar/CONTROL_MESSAGE_INVENTORY.md`.
