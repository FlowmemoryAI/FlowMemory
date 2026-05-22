# FlowMemory Mobile Apps

Status: public mobile-app direction for the current local/test repository release.

FlowMemory's mobile apps are the user-facing control surface for the AI infrastructure network. The protocol makes agent work accountable; the mobile apps make that accountability usable by people operating agents, requesting work, verifying results, and monitoring money-at-risk.

## Why Mobile Matters

Autonomous agents need an operator console that is always available, not just a developer dashboard. The iOS and Android app track is meant to become that console:

- task inbox for objective Agent Bonds work;
- agent passport and reputation viewer;
- wallet and budget monitor for stake, fuel, and task escrow;
- verifier and requester review surface;
- receipt, evidence, and Rootflow history browser;
- recourse quote and failure-waterfall viewer;
- public-agent launch and swarm monitoring surface;
- push-notification target for disputes, slashing risk, verification deadlines, and operator actions.

That is the public selling point: FlowMemory is not only backend protocol infrastructure. It is an AI accountability network with mobile operator surfaces for the humans and organizations supervising agents.

## What Exists In This Repo Today

The committed app surface is the shared React/Vite dashboard in `apps/dashboard`. It is used for browser, desktop, and mobile shells.

Current committed mobile state:

- Android Capacitor shell exists at `apps/dashboard/android`.
- Android web assets are synced from the dashboard build.
- Android debug APK builds are wired in `.github/workflows/wallet-release.yml`.
- Desktop builds are wired through Electron.
- iOS is part of the product direction but no Xcode project is committed yet. Do not claim an iOS build exists until `apps/dashboard/ios` and the corresponding CI/release path are added.

## Android Build Path

```powershell
npm install --prefix apps/dashboard
npm run mobile:android:sync --prefix apps/dashboard
```

Building an APK also requires Java and the Android SDK:

```powershell
npm run mobile:android:debug --prefix apps/dashboard
```

CI can build Android artifacts through the `FlowMemory app release` workflow.

## iOS Build Path

The iOS app is a planned sibling shell around the same FlowMemory dashboard/mobile UI. The public repo should not advertise a runnable iOS build until all of the following exist:

- `apps/dashboard/ios` Xcode project;
- Capacitor iOS dependency and sync script;
- macOS CI build lane;
- documented signing boundary that does not require committed secrets;
- public tester instructions for iOS simulator/device testing.

## What The Mobile App Is Used For

The mobile app is intended to answer five operator questions quickly:

1. **What are my agents doing?**
   - active tasks, accepted bonds, memory updates, and public-agent status.
2. **What can I trust?**
   - verifier reports, receipts, evidence commitments, and replayable Rootflow transitions.
3. **Where is money at risk?**
   - escrow, stake, memory fuel, recourse coverage, loss caps, and pending disputes.
4. **What needs human action?**
   - verification deadlines, challenge windows, failed submissions, slashing paths, and recovery steps.
5. **What history can this agent carry forward?**
   - AgentMemoryView, passport capacity, reputation deltas, task receipts, and reusable memory proofs.

## Public Claim Boundary

Allowed:

- FlowMemory has a committed Android shell for the dashboard/workbench.
- FlowMemory is developing mobile operator surfaces for iOS and Android.
- The mobile app direction is a major part of the AI infrastructure network because it gives humans a usable control plane for agent accountability.

Not allowed yet:

- finished iOS app;
- App Store or Play Store availability;
- production mobile wallet custody;
- push notifications running in production;
- real-value mobile launch approval;
- audited mobile security posture.

## Next Mobile Hardening Steps

- Rename remaining internal wallet labels to FlowMemory app language where it does not break package identifiers.
- Add iOS Capacitor project and macOS CI only when the app shell can be built reproducibly.
- Add mobile-specific dashboard routes for Agent Bonds, public-agent status, receipts, and operator alerts.
- Add mobile tester lanes for Android debug APK and, later, iOS simulator.
