# Decision 0001: FlowRouter V0 Scope

Date: 2026-05-13

## Status

Accepted for V0 research package.

## Context

FlowRouter needs to be concrete enough for hardware, dashboard, services, and field-test agents to share packet shapes and operational assumptions. It also needs strict boundaries so the project does not overclaim internet replacement, production manufacturing, hardware trustlessness, appchain operation, or LoRa bandwidth.

## Decision

FlowRouter V0 is a production-shaped proof-of-concept package built around certified commodity router/radio hardware, Raspberry Pi or mini PC compute, NVMe/local cache, Meshtastic/LoRa control signaling, NFC Memory Cartridge metadata, FlowCore light-pipe status, local dashboard feeds, simulator packets, and controlled field-test plans.

V0 packet schemas and simulator outputs are advisory interfaces for later consumers. They are not production protocol commitments.

## Boundaries

- No ISP replacement claim.
- No broadband over LoRa/Meshtastic.
- No custom RF board or antenna design.
- No production manufacturing commitment.
- No passive income promise.
- No full trustlessness claim.
- No production L1/appchain operation.
- No validator or data availability role for hardware nodes.
- No final CAD until physical measurements are sufficient.

## Consequences

- Hardware work can advance through docs, schemas, fixtures, simulator output, and field-test plans before physical CAD.
- Future services and dashboards can consume deterministic sample feeds without depending on hardware availability.
- Hardware security assumptions remain conservative: physical tampering, spoofing, replay, unauthenticated messages, sidecar bandwidth limits, power/thermal risk, storage failure, and operator key exposure are in scope.
