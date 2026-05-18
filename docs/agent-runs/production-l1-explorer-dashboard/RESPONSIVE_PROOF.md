# Responsive Proof

Browser verification command:

```text
npx playwright test docs/agent-runs/production-l1-explorer-dashboard/browser-verify.spec.mjs --browser=chromium --reporter=line
1 passed
```

Evidence paths:

- `docs/agent-runs/production-l1-explorer-dashboard/dashboard-desktop-playwright.png`.
- `docs/agent-runs/production-l1-explorer-dashboard/dashboard-mobile-playwright.png`.
- `docs/agent-runs/production-l1-explorer-dashboard/browser-dom-evidence.json`.

Verified:

- Desktop viewport: `1440x1100`.
- Mobile viewport: `390x900`.
- Required explorer labels visible on both viewports.
- Document width equals viewport width on both viewports.
- No detected overlapping visible controls after removing clipped mobile/tablet switcher behavior.
- Raw JSON and long IDs render through wrapping/truncated hash components rather than forcing page overflow.
