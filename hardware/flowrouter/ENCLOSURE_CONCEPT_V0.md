# FlowRouter Enclosure Concept v0

Last updated: 2026-05-13

This document supports issue #30. It defines the v0 enclosure concept without creating final CAD or production manufacturing assumptions.

## Concept Goal

The enclosure should make FlowRouter feel like a coherent gateway while preserving serviceability, airflow, measurement access, and research safety.

The v0 enclosure is a prototype shell around certified commodity hardware. It does not modify RF paths, does not replace certified radio/router enclosures where that would affect compliance, and does not claim production readiness.

## Visual Direction

- Matte ivory shell.
- Translucent cobalt FlowCore light pipe.
- Small e-paper/OLED status window.
- Front-facing NFC cartridge touch/slot area.
- Scientific-instrument layout with labels, service screws, and visible status hierarchy.

## Draft Layout Envelope

These dimensions are draft layout targets for bench planning only. They are not CAD, manufacturing dimensions, or fit guarantees.

| Envelope | Approximate target | Rationale |
| --- | --- | --- |
| Dev Kit desktop footprint | 220mm x 160mm | Fits common FDM build plates and leaves room for router/compute modules only if selected parts are compact. |
| Dev Kit height | 65mm to 90mm | Allows Pi 5 cooler, small display tilt, cable strain relief, and airflow. |
| NFC cartridge face | 55mm x 35mm | Enough for passive tag/card experiments and visible label area. |
| Display window | 60mm x 35mm | Fits small OLED or 2.13 inch e-paper class modules with bezel tolerance. |
| FlowCore light-pipe window | 8mm to 18mm diameter or width | Large enough to read state without becoming decorative lighting. |
| Sidecar service bay | model-specific | Blocked until chosen Meshtastic device and antenna clearances are measured. |

Any selected router or mini PC that exceeds the draft envelope should use a split shell, sidecar mount, or open-frame fixture instead of forcing unsafe fit.

## Enclosure Profiles

| Profile | Purpose | Boundary |
| --- | --- | --- |
| Open-frame bench rig | Fast measurement, cable access, heat observation. | Primary v0 starting point. Not field rugged. |
| Desktop dev kit shell | Product-shaped arrangement for router, compute, display, LED, NFC, and sidecar. | No sealed thermals; service panels required. |
| Field-test carrier | Cable strain relief, labels, feet, and protected display/NFC surfaces. | Not weatherproof or tamper-resistant. |
| Future production-shaped concept | Visual and ergonomic target for later design. | Not manufacturing CAD or compliance claim. |

## Functional Zones

- Router zone: keeps stock router airflow and port access intact.
- Compute zone: supports Pi 5 or mini PC with cooler access and NVMe service path.
- Cache zone: keeps NVMe thermals visible and serviceable.
- Display zone: visible from normal operator angle, no secret display.
- FlowCore LED zone: light pipe visible without glare or heat pocket.
- NFC cartridge zone: front-accessible, non-metallic read path, removable test fixture.
- LoRa sidecar zone: removable mount with antenna exposure and cable strain relief.
- Cable zone: separates power, Ethernet, USB, display, NFC, and radio leads.

## Airflow Concept

- Preserve router stock vents.
- Keep Pi 5 active cooler or mini PC fan unobstructed.
- Use vertical chimney-style vents where orientation allows.
- Keep NVMe away from stagnant pockets.
- Keep radio sidecar away from hot exhaust.
- Do not add dust screens until airflow loss is measured.

## Service Access

The enclosure must allow access to:

- Router power, WAN, LAN, USB, reset/recovery, and antenna positions.
- Compute power, USB, Ethernet, SD/NVMe service, and fan cleaning.
- Display connector and mounting screws.
- NFC reader and cartridge slot.
- FlowCore LED/light pipe.
- Meshtastic sidecar, antenna, and transmit-disable workflow.

## Display, NFC, And LED Placement

- Display should be visible without opening the enclosure.
- NFC cartridge slot should not require reaching around antennas or power cables.
- FlowCore LED should be visible from across a room but not bright enough to obscure display reading.
- NFC and LED openings should be test coupons before full-panel printing.

## Antenna And Radio Boundary

- Do not print custom antennas.
- Do not bury vendor antennas.
- Do not force unsupported antenna orientation.
- Keep sidecar removable so radio certification assumptions are not blurred by enclosure experiments.
- Record every test antenna configuration.

## Missing Dimensions And Blockers

Final CAD is blocked by:

- Selected router body, vents, ports, and antenna sweep.
- Selected compute and cooler dimensions.
- NVMe adapter height and temperature.
- Display active area and connector path.
- NFC reader/tag read-through distance.
- FlowCore LED/light-pipe geometry.
- Sidecar radio and antenna clearance.
- Power connector bend radius.
- Sustained thermal data inside any shell.

## Success Criteria

- Operator can read status and access NFC cartridge without moving network cables.
- Router and compute can be serviced without destructive disassembly.
- Airflow remains measurable and unobstructed.
- Radio sidecar stays removable and region-compliant.
- The concept does not imply weatherproofing, tamper resistance, or production readiness.
