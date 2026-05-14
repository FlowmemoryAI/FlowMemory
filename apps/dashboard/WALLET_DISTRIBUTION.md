# Flowchain Wallet Distribution

The wallet is distributed as native desktop builds through Electron and as a native Android shell through Capacitor.

## Local Windows Desktop Build

```powershell
npm run desktop:installer:win --prefix apps/dashboard
```

Artifacts are written to `apps/dashboard/release/`.

For a local unsigned unpacked build plus zip:

```powershell
npm run desktop:pack --prefix apps/dashboard
```

## Android Build

The Android app source lives in `apps/dashboard/android`.

```powershell
npm run mobile:android:sync --prefix apps/dashboard
```

Building an APK requires Java and the Android SDK. On CI, `.github/workflows/wallet-release.yml` builds a debug APK automatically. For a signed release APK, add these repository secrets:

- `FLOWCHAIN_ANDROID_KEYSTORE_BASE64`
- `FLOWCHAIN_ANDROID_KEYSTORE_PASSWORD`
- `FLOWCHAIN_ANDROID_KEY_ALIAS`
- `FLOWCHAIN_ANDROID_KEY_PASSWORD`

## Public Downloads

Run the `Wallet release` GitHub workflow manually for downloadable CI artifacts, or push a tag like:

```powershell
git tag wallet-v0.0.0
git push origin wallet-v0.0.0
```

Tagged runs publish a GitHub Release containing the desktop and Android artifacts.
