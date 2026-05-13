# FlowRouter v0 Research BOM

Last updated: 2026-05-13

This is a research BOM, not a procurement list or manufacturing commitment. Every item is a candidate class until measured, sourced, and validated in a field test.

## BOM Rules

- Use certified commodity router and radio hardware.
- Prefer parts with documented recovery, replacement, and support paths.
- Prefer modular parts that can be removed without reprinting the enclosure.
- Do not design custom RF boards, amplifiers, antennas, or production PCBs.
- Do not treat this BOM as a sellable SKU definition.

## Core Gateway Candidates

| Component | Dev Kit candidate | Pro/Vault candidate | Notes |
| --- | --- | --- | --- |
| Router | OpenWrt One or GL-MT3000 | GL-MT6000 or x86_64 OpenWrt mini PC | Router choice controls enclosure size, thermal behavior, port access, and recovery plan. |
| Compute | Raspberry Pi 5, 8GB | x86_64 mini PC, 8GB+ RAM | Pi 5 is better for visible hardware integration; mini PC is better for cache and sustained services. |
| Storage | 256GB NVMe | 1TB NVMe | NVMe cache is local/offline and pruneable. Use microSD only for boot or non-write-heavy roles. |
| Display | 1.3-2.4 inch OLED or 2.13-2.9 inch e-paper | Larger e-paper or status OLED plus dashboard | Display shows safe status only, never secrets. |
| FlowCore LED | Off-the-shelf blue LED module/light pipe | Serviceable LED module with diffuser/light pipe | Use clear state map and current limiting. |
| NFC | USB NFC reader or GPIO/I2C reader module | Same, plus replaceable cartridge bay | V0 reads tags/pointers; no secret storage on tags. |
| Sidecar radio | Meshtastic-compatible USB/BLE device | Meshtastic-compatible device with external antenna path as certified | Region variant must match test location. |
| Power | Vendor router PSU plus Pi 5 5V/5A USB-C supply | Vendor mini PC PSU plus powered USB hub if needed | Measure total draw before enclosure. |
| Cooling | Pi 5 Active Cooler and router stock cooling | Mini PC stock cooling, NVMe thermal pad, enclosure airflow | No sealed enclosure without thermal data. |

## Required Parts For A FlowRouter Dev Kit

Estimated costs are broad United States street-price planning ranges as of 2026-05-13. They are not quotes, procurement instructions, or production commitments.

| Part class | Example vendor/device | Expected range | Required for v0? | Notes |
| --- | --- | --- | --- | --- |
| OpenWrt router | OpenWrt One, GL.iNet GL-MT3000, GL.iNet GL-MT6000 | USD 90-200 | Yes | Select one. The router handles normal WiFi/Ethernet paths. |
| Local compute | Raspberry Pi 5 8GB or small x86_64 mini PC | USD 80-300 | Yes | Pi 5 is best for visible dev-kit integration; mini PC is better for sustained cache/services. |
| Compute power supply | Raspberry Pi 27W-class USB-C PSU or mini PC vendor PSU | USD 10-40 | Yes | Use vendor-recommended supply; avoid marginal USB power. |
| Compute cooling | Raspberry Pi Active Cooler or mini PC stock cooler | USD 5-35 | Yes | Required before sustained cache/logging tests. |
| NVMe adapter | Raspberry Pi M.2 HAT+ or mini PC internal M.2 slot | USD 12-40 | Yes for NVMe cache tests | Adapter dimensions and SSD height are CAD blockers. |
| NVMe SSD | 256GB NVMe SSD | USD 20-45 | Yes for Dev Kit cache | Use as bounded cache, not permanent source of truth. |
| Meshtastic sidecar | RAK WisBlock, LilyGO, Heltec, or similar Meshtastic-compatible device | USD 25-100 | Yes for issue #12 tests | Must match local region and use supported antenna. |
| Display | Small OLED or e-paper module | USD 5-35 | Yes for product-shaped prototype | Shows safe local status only. |
| Blue FlowCore LED | Off-the-shelf LED module plus diffuser/light-pipe material | USD 2-20 | Yes for product-shaped prototype | No high-brightness sealed heat pocket. |
| NFC reader | USB NFC reader or PN532-style module | USD 10-50 | Yes for cartridge research | Reads pointers/IDs only; no secrets on tags. |
| NFC tags/cards | NTAG-style cards, stickers, or tokens | USD 5-20 | Yes for cartridge research | Test read range through printed material. |
| Prototype fasteners | M2.5/M3 screws, standoffs, inserts, labels | USD 10-35 | Yes | Must remain serviceable. |
| Printed prototype material | PETG filament | USD 20-35 | Yes for enclosure tests | PETG is default; final CAD remains blocked on measurements. |

Approximate Dev Kit planning range: USD 300-900 depending on router, compute, display, sidecar, and tools already available.

## Optional Parts And Test Equipment

| Part class | Example | Expected range | Use |
| --- | --- | --- | --- |
| Larger NVMe SSD | 1TB NVMe | USD 50-120 | Pro/Vault cache and long log tests. |
| Powered USB hub | Known-good USB 3 hub | USD 20-60 | Sidecar, NFC, and storage stability tests. |
| USB Ethernet adapter | Known Linux-compatible adapter | USD 15-45 | Raspberry Pi router experiments. |
| External switch | Small unmanaged/managed switch | USD 20-80 | LAN test topology. |
| E-paper display variant | 2.13-2.9 inch module | USD 15-45 | Persistent status screen tests. |
| Thermal probes | USB thermometer, IR thermometer, or thermocouple logger | USD 15-100 | Thermal validation before enclosure. |
| USB power meter | USB-C PD power meter | USD 15-60 | Pi/sidecar power budget. |
| Kill-A-Watt style meter | AC power meter | USD 20-40 | Router/mini PC draw. |
| ASA filament | Known printer-compatible ASA | USD 25-45 | Higher-temperature enclosure coupons. |
| TPU filament | Shore 95A TPU | USD 20-40 | Feet, bumpers, strain relief. |
| Label printer | Durable labels | USD 30-120 | Field-test labeling. |

## Missing Dimensions For BOM Lock

The BOM cannot become procurement-stable until these dimensions are captured for the selected parts:

- Router exact body, port, vent, antenna, button, and recovery clearances.
- Compute board/chassis, cooler height, connector access, and mounting holes.
- NVMe adapter and SSD height including heatsink or thermal pad.
- Display PCB, active area, connector, and cable path.
- NFC reader antenna center and tag read range through selected material.
- LED module, diffuser, and light-pipe geometry.
- Sidecar radio body, antenna sweep, and cable exit.
- Power connector clearance and safe cable bend radii.
- Printed material shrinkage and insert hole tolerances.

## Recommended OpenWrt Router Options

| Device | Why consider it | V0 caution |
| --- | --- | --- |
| OpenWrt One | Clean OpenWrt baseline with recovery-friendly design and M.2 option. | Availability and exact mechanical dimensions must be verified before enclosure work. |
| GL.iNet GL-MT6000 | Strong router with 2.5G ports, WiFi 6, USB 3.x, RAM, and eMMC. | Ships with vendor OpenWrt fork; tests must record OEM vs official OpenWrt. |
| GL.iNet GL-MT3000 | Portable travel-router candidate with USB-C power and USB 3.0. | Fewer ports and less RAM; best for mobile experiments. |
| x86_64 mini PC with OpenWrt | Strongest lab routing/cache platform. | Model-specific thermals, NICs, BIOS behavior, and power draw vary. |

## Pi 5 Compute Package

Minimum candidate:

- Raspberry Pi 5, 8GB.
- Raspberry Pi 27W-class USB-C supply.
- Raspberry Pi Active Cooler.
- M.2 HAT+ or equivalent supported NVMe adapter.
- 256GB NVMe SSD.
- Short, strain-relieved USB cable to sidecar radio if not using BLE/Wi-Fi.
- GPIO-safe LED/display/NFC wiring only after power budget review.

V0 preference:

- Pi 5 for FlowRouter Dev Kit and Beacon-style visible prototypes.
- Mini PC for Pro, Vault, Forge, and longer-duration cache tests.

## Display Package

Candidate classes:

- I2C OLED for fast status and compact wiring.
- SPI e-paper for persistent low-power state.
- Router stock LEDs plus web dashboard for the lowest-risk early test.

Status fields:

- Power state.
- Upstream internet state.
- LAN-only state.
- Last verified sync time.
- Cache warning.
- Thermal warning.
- LoRa sidecar warning.

Blocked until measured:

- Display window size.
- Viewing angle.
- Cable routing.
- Mounting tabs.
- Service access.

## NFC Cartridge Package

Candidate classes:

- USB NFC reader for fastest lab integration.
- PN532-style module for embedded dev kit experiments.
- Passive NTAG-style cards or tokens for cartridge IDs.
- Printed cartridge shell with NFC tag pocket after dimensions are known.

V0 tag content:

- Cartridge ID.
- Human-safe label.
- Hash or content pointer.
- Schema version.
- Optional expiration or test batch marker.

V0 tag non-content:

- No private keys.
- No seed phrases.
- No raw AI memory.
- No large artifacts.

## Meshtastic/LoRa Sidecar Package

Candidate classes:

- USB-connected Meshtastic device.
- BLE-connected Meshtastic handheld/module.
- RAK WisBlock Meshtastic build using region-appropriate radio module.
- LilyGO or Heltec Meshtastic-compatible boards if regional variant and certification posture are acceptable for the test.

Required checks:

- Frequency variant matches region.
- Stock antenna or vendor-supported antenna is used.
- Firmware region is set before transmit.
- Radio can be disabled for bench work.
- Sidecar can be physically separated from noisy compute/storage if needed.

## Hardware Tier BOM Summary

| Tier | Candidate BOM shape |
| --- | --- |
| FlowRouter Dev Kit | GL-MT3000 or OpenWrt One, Raspberry Pi 5, 256GB NVMe, OLED/e-paper, blue LED, USB NFC reader, USB/BLE Meshtastic sidecar, PETG open frame. |
| FlowRouter Pro | GL-MT6000 or x86 OpenWrt mini PC, stronger mini PC compute, 1TB NVMe, larger display, serviceable LED/NFC, measured fan path. |
| FlowMemory Beacon | Small Meshtastic node, e-paper/OLED, blue LED, optional NFC tag reader, battery/USB power notes. |
| FlowMemory Vault | Mini PC or Pi 5 with larger NVMe, display, NFC cartridge workflow, LAN-only dashboard, tamper notes. |
| FlowMemory Forge | Lab machine, printer/calibration tools, measurement fixtures, USB sidecars, spare radios, thermal probes. |
| FlowMemory Atlas | Field mapping kit with router, sidecar, GPS-capable Meshtastic device if allowed, dashboard notes, logs. |
| Memory Cartridges | Passive NFC tags, printed shells after measurement, labels, optional removable SSD carrier concept for later review. |

## Excluded From V0 BOM

- Custom RF PCB.
- RF power amplifier.
- Unverified antennas.
- Cellular modem SKU commitment.
- Battery/solar product system.
- Production case hardware.
- Tamper-resistant enclosure claim.
- Paid relay/mining/passive-income hardware.
