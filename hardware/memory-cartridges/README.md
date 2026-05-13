# Memory Cartridges

Last updated: 2026-05-13

Memory Cartridges are the FlowMemory hardware concept for physical memory identity, cache pointers, and operator-visible artifact workflows. V0 keeps this research-safe by using NFC tags and optional removable-media notes, not secret-bearing production cartridges.

## V0 Role

A Memory Cartridge may represent:

- A physical label for a memory namespace.
- A pointer to an off-chain artifact set.
- A content hash or compact digest.
- A test batch identifier.
- A cache import/export workflow marker.

It is not:

- A seed phrase holder.
- A private-key token.
- A trusted proof device.
- A production secure element.
- A guarantee that referenced artifacts are available or verified.

## NFC Assumptions

- Use passive NFC tags for v0.
- Store short NDEF-style records only.
- Treat tag content as untrusted input.
- Verify any hash or pointer through normal FlowMemory verification paths.
- Do not store secrets, credentials, or raw memory content.
- Record tag type, capacity, read range, and material stack in `../flowrouter/MEASUREMENT_CHECKLIST.md`.

## Candidate Tag Payload

Fields should stay small:

- `fmcart:v0`
- Cartridge ID.
- Namespace or label.
- Content pointer or hash.
- Optional test batch.
- Optional expiration.

## Physical Cartridge Concept

The physical shell can include:

- Printed label area.
- NFC tag pocket.
- Direction marker.
- Write-protect visual marker if removable storage is explored later.
- Color or texture distinction for field sorting.

Final cartridge CAD is blocked until NFC read range, material thickness, reader position, insertion clearance, and labeling behavior are measured.

## Optional Removable Storage Concept

Later research may evaluate a cartridge carrier that holds a removable SSD or USB storage device. That is not a v0 commitment.

Before removable storage is allowed:

- Define malware and autorun assumptions.
- Define encryption and key handling.
- Define mount policy.
- Define write protection.
- Define safe eject.
- Define provenance and cache verification.

## Risks

- Tag cloning.
- Stale pointer reuse.
- Label spoofing.
- Sensitive label leakage.
- Reader placement failures.
- Operator confusion between local cache and verified state.

## Related Docs

- `NFC_CARTRIDGE_V0.md`: first passive NFC cartridge prototype plan.
- `../flowrouter/MEASUREMENT_CHECKLIST.md`: NFC read-through and slot measurements required before CAD.
