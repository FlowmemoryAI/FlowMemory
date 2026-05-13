# FlowRouter v0 Assembly Notes

Last updated: 2026-05-13

These notes describe safe prototype assembly order. They are not production assembly instructions.

## Assembly Principles

- Keep all parts serviceable.
- Use stock enclosures and open frames until thermal data exists.
- Keep radio, antenna, router, compute, display, LED, and NFC wiring separable.
- Label every cable and power supply.
- Do not transmit on LoRa without correct region, antenna, and test plan.
- Do not expose local dashboard or admin ports to the public internet.

## Bench Assembly Sequence

1. Router baseline
   - Record router model, firmware source, firmware version, recovery method, MAC addresses, and port map.
   - Verify LAN access and upstream WAN behavior.
   - Confirm no unsolicited public inbound access is enabled.

2. Compute baseline
   - Assemble Raspberry Pi 5 or mini PC with stock cooling.
   - Install NVMe if used.
   - Record OS image, storage device, power supply, and idle/load temperature.
   - Keep compute on LAN behind the router during early tests.

3. Local cache baseline
   - Create a bounded cache directory.
   - Define max size, retention period, and deletion behavior.
   - Store only test receipts, digests, and logs.
   - Power-cycle and verify recovery behavior.

4. Display baseline
   - Mount display temporarily.
   - Show only safe status fields.
   - Verify readability, cable strain, and heat exposure.
   - Record display dimensions before enclosure work.

5. FlowCore LED baseline
   - Use an off-the-shelf LED module or safe GPIO circuit.
   - Map simple states: booting, online, degraded, local-only, cache warning, thermal warning, sidecar warning.
   - Verify current limiting and avoid enclosed high-brightness heat buildup.

6. NFC cartridge baseline
   - Start with USB NFC reader or dev module.
   - Read passive tags containing only IDs, pointers, labels, and hashes.
   - Treat reads as untrusted until checked by local policy.
   - Record reader range and orientation before printing any cartridge slot.

7. Meshtastic sidecar baseline
   - Use stock certified device/module.
   - Set correct region before transmit.
   - Keep antenna attached for transmit.
   - Send only low-bandwidth messages from `../lora-sidecar/CONTROL_MESSAGE_INVENTORY.md`.
   - Record RSSI/SNR, hop count, loss, retry behavior, and battery/power state if available.

8. Integration test
   - Disconnect upstream internet.
   - Verify LAN dashboard remains reachable.
   - Verify display and LED show local-only or degraded state.
   - Send gateway availability and heartbeat control messages over Meshtastic.
   - Restore upstream internet and verify cache reconciliation notes.

## Cable And Mounting Notes

- Avoid sharp cable bends near USB-C, HDMI, FPC, antenna, and NFC connections.
- Leave clearance for reset buttons, recovery pins, SD/NVMe access, Ethernet latch movement, and antennas.
- Use strain relief for display, NFC, and sidecar cables.
- Keep antennas away from large metal masses, NVMe heat spreaders, and noisy switching supplies where practical.
- Use removable fasteners or tape for early layout work; do not glue service parts.

## Power-Up Checklist

- Correct PSU for each device.
- No exposed conductive debris.
- Antenna attached or LoRa transmit disabled.
- Fan path clear.
- NVMe seated.
- Display cable seated.
- NFC reader connected but not storing secrets.
- Router admin password changed.
- Meshtastic channel keys are test-only and not committed to the repo.

## Stop Conditions

Stop the test if:

- Any component overheats or throttles unexpectedly.
- Power supply voltage/current warnings appear.
- LoRa transmission may be outside local rules.
- The device causes suspected interference.
- The local dashboard exposes secrets or public access.
- Cache content includes private keys, seed phrases, credentials, or sensitive memory artifacts.

## Assembly Blockers Before Final CAD

- Exact router dimensions and port clearances.
- Exact compute dimensions, cooler height, and mounting holes.
- NVMe adapter and SSD height.
- Display active area and bezel.
- NFC read range through chosen material.
- LED/light-pipe geometry.
- Antenna location and cable routing.
- Thermal data under sustained load.
