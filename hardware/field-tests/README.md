# FlowRouter Field Tests

Last updated: 2026-05-13

Field tests must stay controlled, reversible, and honest about limitations. The current package includes a two-node Meshtastic plan and simulator-generated packet fixtures for dry runs before hardware is attached.

## Rules

- Use certified router and radio hardware.
- Set the correct LoRa region before transmit.
- Keep public MQTT disabled unless a test explicitly requires and documents a private broker posture.
- Do not send secrets, large artifacts, model data, media, or raw memory over LoRa.
- Do not claim ISP replacement, production mesh, passive income, full trustlessness, or emergency-service reliability.
- Stop on thermal, power, radio-region, interference, or secret-exposure concerns.

## Plans

- `TWO_NODE_MESHTASTIC_FIELD_TEST.md`: two-node heartbeat, discovery, digest, dashboard, and offline-mode plan.
