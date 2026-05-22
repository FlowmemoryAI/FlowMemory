# FlowMemory App Distribution

The FlowMemory operator app is distributed as native desktop builds through Electron and as a native Android shell through Capacitor. The same React/Vite surface powers the browser dashboard, desktop app, and mobile app shell.

## Local Windows Desktop Build

```powershell
npm run desktop:installer:win --prefix apps/dashboard
```

Artifacts are written to `apps/dashboard/release/`.

For a local unsigned unpacked build plus zip:

```powershell
npm run desktop:pack --prefix apps/dashboard
```


## Mobile Purpose

The Android app is the first committed mobile shell for the FlowMemory operator console. It is used to inspect agent work, Agent Bonds state, task receipts, public-agent status, wallet/budget surfaces, and operator alerts from the AI infrastructure network.

The iOS app is part of the product direction but no Xcode project is committed yet. Do not claim an iOS build exists until `apps/dashboard/ios` and a macOS CI lane are added.

## Android Build

The Android app source lives in `apps/dashboard/android`.

```powershell
npm run mobile:android:sync --prefix apps/dashboard
```

Building an APK requires Java and the Android SDK. On CI, `.github/workflows/wallet-release.yml` builds a debug APK automatically. For a signed release APK, add these repository secrets:

- `FLOWMEMORY_ANDROID_KEYSTORE_BASE64`
- `FLOWMEMORY_ANDROID_KEYSTORE_PASSWORD`
- `FLOWMEMORY_ANDROID_KEY_ALIAS`
- `FLOWMEMORY_ANDROID_KEY_PASSWORD`

Signing inputs must be stored only as repository secrets and must never be committed.

## Public Downloads

Run the `FlowMemory app release` GitHub workflow manually for downloadable CI artifacts, or push a tag like:

```powershell
git tag wallet-v0.0.0
git push origin wallet-v0.0.0
```

Tagged runs publish a GitHub Release containing the desktop and Android artifacts.
