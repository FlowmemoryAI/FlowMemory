# NFC Memory Cartridge v0

Last updated: 2026-05-13

This document supports issue #31. It defines the first Memory Cartridge prototype as a passive NFC tag workflow, not a secure hardware token.

## Objective

Use a physical cartridge to make memory/cache identity visible to an operator while keeping all security claims conservative.

## V0 Cartridge Payload

Recommended compact fields:

| Field | Example | Notes |
| --- | --- | --- |
| `schema` | `fmcart:v0` | Identifies the cartridge format. |
| `cart_id` | short random ID | Human workflows only; not proof of authenticity. |
| `label` | test namespace | Avoid sensitive names. |
| `pointer` | CID, URL, or local namespace | Must be verified through normal paths. |
| `digest` | hash prefix or full hash if space allows | Helps detect obvious mismatch. |
| `batch` | field-test batch | Optional. |
| `expires` | date or epoch | Optional stale-use warning. |

## Tag Content Limits

Do not write:

- Private keys.
- Seed phrases.
- RPC credentials.
- WiFi passwords.
- Meshtastic channel keys.
- Raw AI memory.
- Personal or sensitive labels.
- Large artifact payloads.

## Prototype Hardware

- Passive NTAG-style cards, stickers, or tokens.
- USB NFC reader for first lab tests.
- PN532-style module only after power and mounting are reviewed.
- Printed shell or sleeve only after read-through measurements exist.

## Read Path

1. Operator inserts or taps cartridge.
2. Reader captures small tag payload.
3. Local software treats payload as untrusted.
4. Display shows safe label and local/advisory/verified status.
5. Verification path checks pointer/digest through normal FlowMemory mechanisms when network or cache state allows.

## Measurement Plan

- Measure read range in open air.
- Measure read range through 1mm, 2mm, and 3mm PETG.
- Measure read range through ASA if used.
- Test orientation sensitivity.
- Test effect of nearby screws, labels, cables, display, and LED module.
- Record false read, failed read, and duplicate tag behavior.

## Risks

- Tag cloning.
- Stale pointer reuse.
- Label spoofing.
- Sensitive label leakage.
- Operator confusion between cartridge presence and verified content.
- NFC reader placement failure after enclosure changes.

## Future Threat Model Topics

Before Memory Cartridges can move beyond passive metadata pointers, a separate threat model must define:

- Whether cartridges ever hold encrypted removable media.
- Whether a secure element is needed.
- How cartridge identity is authenticated.
- How cloned tags are detected or tolerated.
- How stale pointers expire.
- How operators distinguish inserted, read, trusted, and verified states.
- How malware, autorun, or unsafe mount behavior is prevented if removable storage is introduced.

## Non-Goals

- No secure element.
- No production cartridge.
- No removable storage commitment.
- No proof-of-memory claim.
- No final cartridge CAD until read range and slot geometry are measured.
