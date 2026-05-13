# FlowRouter v0 Scope

Last updated: 2026-05-13

FlowRouter v0 is a production-shaped research foundation for FlowMemory hardware. It defines the smallest credible gateway shape while staying safely inside commodity hardware, measured prototypes, and low-bandwidth control signaling.

## What FlowRouter v0 Is

FlowRouter v0 is a local gateway research rig built from:

- A certified OpenWrt-capable router for WiFi/Ethernet routing.
- Raspberry Pi 5 or x86_64 mini PC compute for local services, telemetry, and cache control.
- NVMe storage for bounded local/offline artifact and receipt cache experiments.
- Meshtastic/LoRa sidecar for compact control messages.
- E-paper or OLED display for local operator state.
- Blue FlowCore LED light pipe for simple hardware state.
- NFC memory cartridge slot for physical identity, pointers, or removable cache workflows.
- LAN-only local dashboard assumptions.

The v0 question is whether FlowMemory can keep useful local state, compact coordination, and operator clarity during degraded connectivity, then reconcile with normal network paths later.

## What FlowRouter v0 Is Not

FlowRouter v0 is not:

- An ISP replacement.
- A claim that global internet appears without an upstream gateway.
- A production mesh network.
- A passive-income device.
- A full-trustless hardware oracle.
- A production hardware SKU.
- A production firmware distribution.
- A custom RF board, antenna, amplifier, or radio certification project.
- A final CAD package.
- A manufacturing BOM.
- A high-bandwidth LoRa or Meshtastic transport.
- A way to move AI memory, model artifacts, media, or bulk data over LoRa.

## Required Truths

- At least one gateway needs upstream internet for external sync.
- WiFi and Ethernet handle normal data paths.
- Meshtastic and LoRa are low-bandwidth control channels.
- V0 must use certified radio/router hardware in authorized configurations.
- Cached local state is not automatically verified state.
- Operator commands over radio are warnings or queued intent only until authentication, authorization, replay protection, and audit semantics are designed.

## Workstream Boundaries

Research:

- Compare commodity hardware classes and document assumptions.
- Define proof-of-concept questions, field metrics, and open risks.
- Produce notes, diagrams, and decision inputs for later issues.

Field tests:

- Run controlled local tests with explicit start/stop conditions.
- Record observed connectivity, cache, radio, power, thermal, and tamper data.
- Avoid public deployment, public relay behavior, and coverage claims.

Firmware and electrical work:

- Configure supported OpenWrt images, Meshtastic firmware, packages, and local scripts only as needed for measurement.
- Use vendor power supplies and certified off-the-shelf radios.
- Do not design production firmware, custom PCBs, custom RF paths, amplifiers, or antenna systems.

Enclosure work:

- Use temporary mounts, dev cases, labels, airflow notes, and field photos.
- Document cooling constraints before any printed enclosure is considered final.
- Do not produce final CAD, tooling files, production materials, or manufacturing assumptions without measurements.

Operator controls:

- Define local-only status and control expectations for power, upstream connectivity, cache state, and sidecar state.
- Treat remote commands as out of scope until authentication, authorization, audit logs, and failure modes are defined.
- Keep operator controls distinct from dashboard or hardware-console product work.

## Recommended Certified OpenWrt Router Options

Use supported commodity hardware first. Prefer documented OpenWrt support, recovery paths, enough RAM for logging, and USB/M.2/serial access for sidecar and cache experiments.

| Router | V0 role | Assumptions |
| --- | --- | --- |
| OpenWrt One | Clean baseline router | Official OpenWrt-oriented device with recovery-friendly design, 1GB RAM, 2.5G/1G Ethernet, USB serial, and M.2 SSD option. Best first baseline if available. |
| GL.iNet GL-MT6000 / Flint 2 | Higher-throughput router | Strong router-first candidate with WiFi 6, 1GB RAM, 8GB eMMC, USB 3.x, four 1G LAN ports, and two 2.5G ports. Distinguish OEM OpenWrt fork from official OpenWrt image. |
| GL.iNet GL-MT3000 / Beryl AX | Portable field router | Travel-router candidate with WiFi 6, USB 3.0, USB-C power, 512MB RAM, and two Ethernet ports. Useful for mobile field tests, not final product assumptions. |
| x86_64 OpenWrt mini PC | Lab router/cache/control node | Use when tests need more CPU, RAM, SSD, or multiple Ethernet ports. Prefer common Intel NICs, 4GB+ RAM, SSD storage, and measured thermals. |

Avoid unsupported bargain routers unless the research question is specifically hardware compatibility risk.

## Raspberry Pi 5 vs Mini PC Tradeoffs

| Dimension | Raspberry Pi 5 | x86_64 mini PC |
| --- | --- | --- |
| Best use | Visible dev kit, GPIO/display/LED/NFC integration, low-power local services. | Higher-throughput routing, larger cache, stronger local services, multiple NICs. |
| Networking | Built-in Gigabit Ethernet; router use usually needs USB Ethernet, external switch, or separate access point. | Often includes one or more Ethernet ports; multi-NIC models are better router candidates. |
| Storage | M.2 HAT+ gives PCIe 2.0 x1 NVMe path; microSD should not hold write-heavy cache. | Internal NVMe/SATA is usually stronger for cache and logs. |
| Cooling | Active cooling expected under sustained load. | Depends on chassis; fanless needs thermal proof before field use. |
| Power | Use official-class 5V/5A USB-C supply for Pi 5 with peripherals. | Use vendor PSU; measure idle and load draw. |
| Enclosure fit | Good for printed dev case and GPIO peripherals. | Easier to use as black-box compute; harder to integrate cleanly without exact model dimensions. |

## NVMe Storage Assumptions

- NVMe is for bounded local/offline cache, not permanent source of truth.
- 256GB is the recommended v0 default for FlowRouter Dev Kit cache tests.
- 1TB is a reasonable FlowRouter Pro/Vault research target when longer logs or package mirrors are needed.
- Cache entries should prefer hashes, CIDs, compact receipts, state summaries, and provenance metadata.
- Cache retention must be explicit by size and age.
- Cache content that is sensitive must be encrypted at rest or excluded.
- Power-loss recovery and filesystem behavior must be tested before unattended use.

## Display Options

| Option | Fit | Notes |
| --- | --- | --- |
| Small OLED | Fast local status | Useful for IP state, cache state, temperature, and sidecar state. Watch burn-in and cable strain. |
| E-paper | Low-power persistent status | Good for device identity, last sync, and warning state. Refresh is slower; protect display from pressure. |
| Router LEDs only | Minimal baseline | Acceptable for early v0, but insufficient for operator clarity without local dashboard. |

The display should never reveal secrets, private keys, WiFi passwords, channel keys, or sensitive cache labels.

## FlowCore LED Options

- Blue LED behind a light pipe is allowed as a visual state indicator.
- V0 states should stay simple: booting, local-only, online, degraded, cache warning, sidecar warning, thermal warning.
- Use off-the-shelf LED boards or GPIO-compatible modules.
- Add current limiting and follow vendor ratings.
- Avoid high-brightness enclosed LEDs without thermal checks.

## NFC Memory Cartridge Options

- V0 NFC should use off-the-shelf reader modules and passive tags.
- The cartridge should carry a short cartridge ID, content pointer, hash, or label.
- Do not store private keys, seed phrases, or long sensitive data on passive NFC tags.
- Treat cartridge reads as untrusted input until authenticated and checked against expected commitments.
- Cartridge mechanical fit is blocked on measurements in `MEASUREMENT_CHECKLIST.md`.

## LoRa/Meshtastic Module Options

- Use off-the-shelf Meshtastic-compatible devices or certified radio modules for the region.
- Prefer USB/serial/BLE integration before any embedded electrical design.
- Candidate classes: RAK WisBlock Meshtastic builds, LilyGO Meshtastic boards, Heltec Meshtastic boards, or other documented Meshtastic-compatible devices.
- Verify regional frequency variant before purchase or field use.
- Do not design custom RF electronics in v0.
- Do not add amplifiers or unsupported antennas.
- Keep radios connected to suitable antennas before transmit.

## Power Assumptions

- Use vendor-recommended router supplies.
- Raspberry Pi 5 assumes a high-quality 5V/5A USB-C supply when peripherals are attached.
- Mini PCs use vendor PSU and measured draw.
- Displays, NFC, LEDs, and radio sidecars need a power budget before enclosure integration.
- Battery, UPS, solar, and vehicle-power tests are field-test notes only, not product power-system design.

## Cooling Assumptions

- Raspberry Pi 5 should use active cooling under sustained load.
- Mini PCs need measured idle/load temperature and throttling observations.
- Router thermals must be measured before enclosure changes.
- NVMe drives need airflow or thermal pads if logs/cache writes are sustained.
- No sealed printed enclosure is acceptable without thermal measurements.

## Enclosure Assumptions

- V0 can use open test frames, dev cases, bracket prototypes, labels, cable guides, and measured mockups.
- Final CAD is blocked until dimensions, connector clearances, thermal paths, cable bend radii, display windows, NFC field location, antenna placement, and service access are measured.
- Antennas should remain outside or properly exposed by the enclosure according to the device vendor's intended use.
- The enclosure must allow tool access, SD/NVMe service, reset/recovery, and visible warning states.

## 3D Printer And Material Constraints

- Model for common FDM printers first; assume 220mm x 220mm x 250mm as the default build-volume target unless larger hardware requires a split enclosure.
- PETG is the default v0 material for toughness and moderate heat resistance.
- ASA is acceptable for higher-temperature or outdoor-adjacent tests only with ventilation, printer capability, and shrinkage testing.
- TPU is useful for feet, bumpers, cable strain relief, and vibration isolation.
- PLA is acceptable for desk mockups only; do not use it for warm routers, vehicles, sun exposure, or enclosed electronics.
- Use threaded inserts or captured nuts for serviceable assemblies.
- Do not rely on printed plastic as an electrical safety barrier.

## Regulatory Cautions

This document is not legal advice. Operators are responsible for local radio rules.

- Use certified off-the-shelf router and radio hardware in authorized configurations.
- Set the correct Meshtastic region before transmit.
- For United States tests, Meshtastic documents the `US` region as 902-928 MHz with 30 dBm power limit.
- Do not override region, frequency, duty-cycle, or power settings to escape local limits.
- Stop or change a test if harmful interference is suspected.
- Amateur-radio operation needs a separate issue because encryption, identification, operator licensing, and band plans change the design.
- Public marketing, sale, lease, or distribution needs a separate regulatory review before product claims.

## Smallest Useful Proof-of-Concept Questions

1. Can a commodity router and local compute node keep a LAN dashboard reachable when upstream internet is lost?
2. Can a Meshtastic sidecar exchange compact gateway/status messages with another node under degraded IP connectivity?
3. Can NVMe-backed local cache preserve compact receipts, digests, and logs across power loss?
4. Can operators distinguish local-only state from verified state?
5. Can the enclosure concept keep router, compute, NVMe, display, LED, NFC, and sidecar serviceable and cool?
6. What device identity, tamper evidence, and operator-key handling are required before any remote command path is safe?

## References Checked

- OpenWrt Table of Hardware: https://openwrt.org/toh/start
- OpenWrt One: https://openwrt.org/toh/openwrt/one
- OpenWrt GL.iNet GL-MT6000: https://openwrt.org/toh/gl.inet/gl-mt6000
- OpenWrt GL.iNet GL-MT3000: https://openwrt.org/toh/gl.inet/gl-mt3000
- OpenWrt x86 guide: https://openwrt.org/docs/guide-user/installation/openwrt_x86
- OpenWrt extroot guide: https://openwrt.org/docs/guide-user/additional-software/extroot_configuration
- Raspberry Pi 5: https://www.raspberrypi.com/products/raspberry-pi-5/
- Raspberry Pi Active Cooler: https://www.raspberrypi.com/products/active-cooler/
- Raspberry Pi M.2 HAT+: https://www.raspberrypi.com/products/m2-hat-plus/
- Meshtastic LoRa configuration: https://meshtastic.org/docs/configuration/radio/lora/
- Meshtastic channel configuration: https://meshtastic.org/docs/configuration/radio/channels/
- Meshtastic MQTT configuration: https://meshtastic.org/docs/configuration/module/mqtt/
- 47 CFR 15.5: https://www.ecfr.gov/current/title-47/chapter-I/subchapter-A/part-15/subpart-A/section-15.5
- 47 CFR 15.204: https://www.ecfr.gov/current/title-47/chapter-I/subchapter-A/part-15/subpart-C/section-15.204
- 47 CFR 2.803: https://www.ecfr.gov/current/title-47/chapter-I/subchapter-A/part-2/subpart-I/section-2.803
