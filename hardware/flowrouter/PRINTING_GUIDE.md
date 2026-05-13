# FlowRouter v0 Printing Guide

Last updated: 2026-05-13

This guide defines enclosure-printing constraints before final CAD. It intentionally does not create final CAD because required dimensions and thermal measurements are missing.

## Printing Goal

V0 printed parts should support measurement, serviceability, airflow, display/NFC/light-pipe experiments, and field-test handling. They should not imply production readiness.

## Printer Constraints

- Default design target: common FDM printer with about 220mm x 220mm x 250mm build volume.
- Use split panels if router, mini PC, or antenna layout exceeds the build volume.
- Assume 0.4mm nozzle unless a print note says otherwise.
- Design test coupons before full enclosure panels.
- Prefer parts that print without fragile supports around vents, clips, and cable channels.
- Keep wall thickness, standoff geometry, and heat-set insert holes parameterized in CAD later.

## Material Recommendations

| Material | Use | Caution |
| --- | --- | --- |
| PETG | Default v0 material for dev frames, brackets, panels, and light-duty field parts. | Can soften near hot electronics; measure internal temperatures. |
| ASA | Higher-temperature and outdoor-adjacent tests. | Requires enclosed/ventilated printer setup and shrinkage calibration. |
| TPU | Feet, bumpers, vibration pads, cable strain relief, gaskets. | Not for structural electronics mounts. |
| PLA | Desk mockups and fit checks only. | Avoid for warm routers, vehicles, sun, sealed electronics, or field use. |

## Enclosure Features To Prototype

- Removable top or side panel.
- Router service access.
- Compute service access.
- NVMe access or removable cache bay.
- Display window.
- Blue FlowCore LED light pipe.
- NFC cartridge face/slot.
- LoRa sidecar mount and cable exit.
- Antenna clearance without printed plastic forcing unsupported RF geometry.
- Vent paths for router, compute, NVMe, and power supplies.
- Label recesses for device ID and test batch.

## Airflow And Thermal Rules

- Do not enclose a router in printed plastic without measuring stock-case temperature first.
- Do not place Pi 5, mini PC, NVMe, or radios in a sealed enclosure.
- Keep inlet and exhaust paths separate where possible.
- Avoid trapping hot air behind e-paper/OLED modules.
- Measure temperatures with the prototype in its real orientation.
- Add dust screens only after airflow loss is measured.

## NFC And Light Pipe Rules

- NFC slot geometry is blocked until reader/tag range is measured through PETG and ASA samples.
- Do not put metal fasteners or foil-backed labels between reader and tag.
- Keep the FlowCore LED light pipe removable.
- Avoid LED brightness that washes out display readability or creates heat in a sealed pocket.

## Antenna And Radio Rules

- V0 printed parts must not create a custom antenna system.
- Keep vendor antennas exposed in normal orientation.
- Do not bury antennas near metal fasteners, NVMe heat spreaders, batteries, or dense wire bundles.
- Do not print brackets that require unsupported antenna modifications.
- Record whether a test used stock antenna, vendor-approved antenna, or radio transmit disabled.

## Fasteners And Serviceability

- Prefer M2.5/M3 screws, captured nuts, or heat-set inserts after test coupons.
- Avoid plastic threads for parts expected to be opened repeatedly.
- Do not glue radios, storage, displays, or NFC readers.
- Leave room for labels, cable strain relief, and connector latch access.

## Pre-CAD Test Coupons

Print and measure:

- Screw boss and insert samples.
- Vent grille samples.
- PETG and ASA NFC read-through samples.
- Light-pipe samples.
- Cable channel samples for USB-C, Ethernet, display, and antenna pigtails.
- Snap-fit samples only if service life is measured.

## Final CAD Gate

Final CAD stays blocked until `MEASUREMENT_CHECKLIST.md` has enough completed measurements for:

- Selected router.
- Selected compute.
- Selected storage adapter.
- Display.
- NFC reader/tag stack.
- LED/light pipe.
- Sidecar radio.
- Cable exits and bend radii.
- Thermal load.
- Printer calibration and material shrinkage.
