# FlowRouter v0 Measurement Checklist

Last updated: 2026-05-13

Final CAD is blocked until these measurements exist for the selected hardware. Record measured values, device revisions, measurement method, and photos where useful.

## Selected Hardware

- [ ] Router model, revision, firmware source, and power supply.
- [ ] Compute model, revision, cooler, power supply, and OS image.
- [ ] NVMe adapter, SSD model, heatsink/thermal pad.
- [ ] Display model and interface.
- [ ] NFC reader model and tag type.
- [ ] LED/light-pipe module.
- [ ] Meshtastic/LoRa sidecar model, frequency variant, antenna, firmware version.

## Router Measurements

- [ ] Overall width, depth, height.
- [ ] Foot height and location.
- [ ] Ethernet port positions and latch clearance.
- [ ] USB/serial/power connector positions.
- [ ] Button/recovery access.
- [ ] Antenna dimensions and rotation sweep if external.
- [ ] Stock-case vent locations.
- [ ] Idle temperature in open air.
- [ ] Sustained routing temperature in open air.
- [ ] Recovery procedure clearance needs.

## Compute Measurements

- [ ] Board or chassis dimensions.
- [ ] Mounting hole locations.
- [ ] Cooler height.
- [ ] GPIO/header clearance.
- [ ] USB/Ethernet/HDMI/power connector clearance.
- [ ] NVMe adapter height and overhang.
- [ ] Idle temperature.
- [ ] Sustained cache/logging temperature.
- [ ] Throttling behavior.

## Storage Measurements

- [ ] NVMe form factor.
- [ ] SSD height with label/heatsink.
- [ ] Thermal pad or heatsink clearance.
- [ ] Write-heavy temperature after 15 minutes.
- [ ] Write-heavy temperature after 60 minutes.
- [ ] Power-loss recovery observation.
- [ ] Filesystem check behavior after forced power loss in a disposable test image.

## Display Measurements

- [ ] PCB width, height, thickness.
- [ ] Active display area.
- [ ] Bezel/window size.
- [ ] Connector location.
- [ ] Cable bend radius.
- [ ] Readability in expected orientation.
- [ ] Heat exposure from nearby compute/router.

## NFC Cartridge Measurements

- [ ] Reader PCB dimensions.
- [ ] Antenna field center.
- [ ] Read range in open air.
- [ ] Read range through 1mm, 2mm, and 3mm PETG.
- [ ] Read range through 1mm, 2mm, and 3mm ASA if ASA is considered.
- [ ] Tag dimensions.
- [ ] Cartridge insertion/removal clearance.
- [ ] Effect of nearby screws, magnets, labels, and cables.

## FlowCore LED Measurements

- [ ] LED module dimensions.
- [ ] Operating current.
- [ ] Heat after 30 minutes.
- [ ] Light-pipe diameter/length.
- [ ] Visible states under room light.
- [ ] Display glare impact.

## Sidecar Radio Measurements

- [ ] Device dimensions.
- [ ] Antenna orientation and clearance.
- [ ] USB/BLE/serial connection path.
- [ ] Radio-disabled bench mode confirmed.
- [ ] Region setting confirmed before transmit.
- [ ] RSSI/SNR for short field test.
- [ ] Packet loss/retry notes.
- [ ] Heat near compute/storage.

## Power Measurements

- [ ] Router idle draw.
- [ ] Router load draw.
- [ ] Compute idle draw.
- [ ] Compute load draw.
- [ ] NVMe write load draw if measurable.
- [ ] Display/LED/NFC/sidecar draw.
- [ ] Total draw with all peripherals.
- [ ] PSU headroom.
- [ ] Brownout or undervoltage warnings.

## Enclosure And Printing Measurements

- [ ] Printer build volume.
- [ ] Material used and brand.
- [ ] Dimensional accuracy coupon.
- [ ] Heat-set insert coupon.
- [ ] Vent coupon airflow observation.
- [ ] PETG shrink/fit notes.
- [ ] ASA shrink/fit notes if used.
- [ ] TPU foot/bumper fit notes if used.
- [ ] Minimum service clearance around every removable part.

## Missing Measurements Summary

Until measured, assume unknown:

- Final enclosure dimensions.
- Display window geometry.
- NFC cartridge slot geometry.
- Light-pipe geometry.
- Antenna placement.
- Cable bend radii.
- Thermal margin in any printed enclosure.
- Power budget with all peripherals attached.
