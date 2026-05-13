# LoRa Sidecar

Last updated: 2026-05-13

The LoRa sidecar is FlowRouter v0's low-bandwidth control-signaling path. It is not normal internet bandwidth, not a payload network, and not a production mesh deployment.

## Role

The sidecar may send and receive:

- Node heartbeat.
- Gateway availability.
- FlowPulse digest.
- Artifact availability digest.
- Compact receipt reference.
- Field diagnostic.
- Emergency/local signal.
- Operator command warning.

The sidecar must not send:

- AI memory artifacts.
- Model data.
- Media.
- Bulk files.
- Normal app traffic.
- Secrets, private keys, seed phrases, WiFi passwords, or channel keys.

## Hardware Assumptions

- Use off-the-shelf Meshtastic-compatible devices or certified radio modules for the test region.
- Prefer USB, BLE, serial, or Wi-Fi/MQTT integration over embedded electrical design.
- Keep the radio removable from the FlowRouter enclosure.
- Use stock or vendor-supported antennas.
- Do not add amplifiers.
- Do not create custom RF boards.
- Confirm the hardware frequency variant before field use.

## Integration Modes

| Mode | Fit | Boundary |
| --- | --- | --- |
| USB serial | Best early lab path. | Requires cable strain relief and serial permissions. |
| BLE | Useful for handheld sidecars. | Pairing and reliability must be measured. |
| Wi-Fi/MQTT | Useful for lab gateway experiments. | Prefer private broker; downlink is risky and must be explicit. |
| Embedded UART/I2C/SPI | Later prototype path. | Not v0 default; requires electrical review. |

## Radio Configuration Assumptions

- Set Meshtastic region before transmit.
- Use conservative hop limits.
- Use short messages and low frequency.
- Record modem preset, hop limit, channel name, PSK posture, and MQTT settings in field notes.
- Treat OK-to-MQTT as policy metadata, not cryptographic enforcement.
- Disable transmit during bench work that lacks antenna, region, or test plan.

## Payload Budget

FlowRouter V0 should treat LoRa/Meshtastic as a scarce control channel:

- Target compact payloads of 160 bytes or less before transport overhead where practical.
- Treat about 200 bytes as a practical upper bound for application-level message design.
- Prefer binary-inspired fields, short enums, hashes, prefixes, counters, and bitsets.
- Send digests, references, and state summaries instead of full logs or artifacts.
- Rate-limit repeated messages and avoid chatty telemetry loops.

Never send over LoRa:

- Model weights.
- Large artifacts.
- Media.
- Raw AI memory payloads.
- Full verifier reports.
- Full receipt bodies.
- Secrets, private keys, seed phrases, credentials, WiFi passwords, or channel keys.

## Security Requirements Before Control

Before a radio message can change local FlowRouter state, the design needs:

- Device identity model.
- Message authentication.
- Replay protection.
- Monotonic sequence or nonce handling.
- Time or freshness model that works offline.
- Operator authorization.
- Audit log.
- Failsafe behavior.

V0 operator command messages are warnings or test intents only; they do not execute privileged actions.

## Related Docs

- `CONTROL_MESSAGE_INVENTORY.md`: candidate compact control messages.
- `TWO_NODE_DEMO_PLAN.md`: controlled two-node demo plan for advisory control signaling.
