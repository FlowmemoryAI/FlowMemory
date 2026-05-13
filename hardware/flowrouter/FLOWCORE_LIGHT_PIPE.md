# FlowCore Light-Pipe Prototype

Last updated: 2026-05-13

This document supports issue #32. It defines a research-safe blue FlowCore LED/light-pipe concept for FlowRouter v0.

## Role

The FlowCore light pipe is an at-a-glance local status indicator. It complements the display and local dashboard; it is not a security indicator by itself.

## Visual Direction

- Shell direction: matte ivory prototype enclosure.
- Light-pipe direction: translucent cobalt FlowCore window or pipe.
- Overall feel: scientific instrument, bench gateway, labeled test hardware.
- Avoid gamer RGB, decorative status effects, or ambiguous colors.

## V0 Status Map

| State | LED behavior | Meaning |
| --- | --- | --- |
| Booting | Slow cobalt pulse | Hardware is starting or local status is not ready. |
| Online | Solid cobalt | LAN dashboard and upstream path appear available. Advisory only. |
| Syncing | Soft double pulse | Local cache or digest state is reconciling over normal network paths. |
| Verified | Solid cobalt with brief confirmation pulse | The displayed item is verified by normal verifier/indexer path. |
| Unresolved | Slow blink | Local/advisory state exists but is not verified. |
| Offline | Two short pulses with long gap | LAN-only or upstream unavailable. |
| Error | Fast blink | Power, thermal, cache, sidecar, or validation error needs operator attention. |

## Candidate Parts

- Off-the-shelf 5V or 3.3V blue LED module.
- GPIO-safe LED board with current limiting.
- Short acrylic light pipe.
- Printed PETG diffuser test coupon.
- TPU gasket or bumper around light-pipe opening.

No custom PCB is required for v0.

## Electrical Boundaries

- Use vendor-rated LED current.
- Include current limiting if the module does not provide it.
- Do not drive high-current LED strips from Raspberry Pi GPIO.
- Avoid visible wiring strain near the display and NFC reader.
- Keep LED power budget in the total system power measurement.

## Thermal And Usability Checks

- Measure LED pocket temperature after 30 minutes.
- Check glare against OLED/e-paper display.
- Check visibility in room light and dim light.
- Check whether the state pattern is distinguishable without reading docs.
- Confirm light-pipe removal does not require removing router or compute.

## Non-Goals

- No production electrical design.
- No custom LED PCB.
- No safety-critical status claim.
- No hidden operator command channel.
- No final light-pipe CAD until geometry and thermals are measured.
