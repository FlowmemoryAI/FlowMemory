# FlowMemory Dashboard And Operator App

Fixture-backed operator app for inspecting FlowMemory V0 launch data, Agent Bonds, public-agent activity, receipts, verifier reports, hardware signals, and mobile/desktop packaging.

## Run Locally

From the repository root:

```powershell
npm install
npm install --prefix apps/dashboard
npm run flowmemory:generate
npm run dev --prefix apps/dashboard
```

The app starts from committed/generated FlowMemory fixtures. It does not claim hosted production data, value-bearing wallet support, token pricing, or production deployment.

## Test And Build

```powershell
npm test --prefix apps/dashboard
npm run build --prefix apps/dashboard
```

The public launch gate also runs the dashboard lane through:

```powershell
npm run public:test:dashboard
```

## Desktop App

Electron packages the same dashboard surface as the FlowMemory desktop operator app:

```powershell
npm run desktop:pack --prefix apps/dashboard
```

Release workflows publish desktop artifacts under FlowMemory branding.

## Android App

The committed Android Capacitor shell lives under `apps/dashboard/android` and uses the shared dashboard build:

```powershell
npm run mobile:android:sync --prefix apps/dashboard
```

Debug APK builds require a local Java/Android toolchain:

```powershell
npm run mobile:android:debug --prefix apps/dashboard
```

Android release signing secrets use `FLOWMEMORY_ANDROID_*` names and must never be committed.

## iOS Track

iOS is part of the FlowMemory operator-app product direction, but no Xcode project or iOS CI lane is committed yet. Keep iOS claims in docs framed as planned until a reproducible macOS build lane exists.

## Public Views

The public app navigation focuses on:

1. **Overview** for launch fixture metrics, recent FlowPulse observations, verifier attention, hardware risk, and public-agent state.
2. **Flow Memory** for MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, and RootflowTransition state.
3. **FlowPulse** for event observations and receipt linkage.
4. **Rootfields** for namespaces and committed roots.
5. **Work receipts** and **verifier reports** for objective work evidence.
6. **Agent Bonds** for task accountability, challenge, recourse, and settlement views.
7. **Public agents** for agent/swarm launch state.
8. **Hardware** for FlowRouter POC heartbeats and alerts.
9. **Raw JSON** only when a reviewer asks for the payload behind the UI.

## Fixture Sync

The `dev` and `build` scripts run `npm run sync:fixtures`, which copies the canonical dashboard fixture and bounded local generated launch data into the Vite public data folder before the app starts or builds.

Canonical source fixture:

```text
fixtures/dashboard/flowmemory-dashboard-v0.json
```

Runtime app copy:

```text
apps/dashboard/public/data/flowmemory-dashboard-v0.json
```

Do not edit generated runtime copies by hand; regenerate from the service packages instead.
