# @capgo/capacitor-live-activities demo

Capacitor example app for the local `@capgo/capacitor-live-activities` plugin (`file:..`). It includes a **LiveActivities** Widget Extension that uses `CapgoLiveActivityAttributes` and the shared JSON layout renderer from the plugin.

## What you can try

- **Start delivery**: starts a delivery-tracking Live Activity (lock screen and Dynamic Island on supported devices).
- **Update status**: advances the demo through preparing, on the way, arriving, and delivered.
- **End activity**: ends the Live Activity.
- **Refresh**: lists activities from `getAllActivities()` and shows the ActivityKit push token when available.
- **Plugin version**: reads the native plugin version.

## Prerequisites

- Node.js 22 or newer and npm (the root `bun run build` runs npm scripts for docgen and TypeScript)
- [Bun](https://bun.sh) for installs and example-app scripts (same as the parent repo)
- Xcode 26.0 or newer
- Physical iPhone or simulator on **iOS 16.1+** (Dynamic Island needs a supported device model)
- Live Activities enabled for the app in **Settings > (app name)**

## Run in the browser (web shell only)

From the repository root, build the plugin once so `dist/` exists for the `file:..` dependency:

```bash
bun install
bun run build
cd example-app
bun install
bun run start
```

Live Activities APIs are unavailable on web; the UI still loads for layout checks.

## Run on iOS (device or simulator)

From the repository root:

```bash
bun install
bun run build
cd example-app
bun install
bun run build
bunx cap sync ios
python3 ios/configure-live-activities-target.py
```

Open the workspace in Xcode:

```bash
bunx cap open ios
```

In Xcode:

1. Select the **App** scheme and your simulator or device.
2. Confirm **App** and **LiveActivitiesExtension** targets use deployment target **iOS 16.1+**.
3. For a physical device: select your **Development Team** on **App** and **LiveActivitiesExtension**. The committed project has no team set, so signing fails until you pick one.
4. If your team does not own `app.capgo.live.activities`, choose a unique app bundle ID and a matching extension ID (for example `your.team.id` and `your.team.id.LiveActivities`). Update both `appId` values in `capacitor.config.ts` (`appId` and `plugins.CapacitorUpdater.appId`) before `bunx cap sync ios`. In Xcode, set the App and LiveActivitiesExtension bundle identifiers to those IDs for both Debug and Release. Register both App IDs in the Apple Developer portal.
5. Register an App Group for that team. The plugin derives the group as `group.<app bundle ID>.liveactivities` (the committed demo uses `group.app.capgo.live.activities.liveactivities`). Keep every copy aligned with that derived id: App entitlements, LiveActivities entitlements, and `CapgoLiveActivityWidget.swift` `appGroupIdentifier()`.
6. To test the **ActivityKit push token** card: on the **App** target (not the extension), enable **Signing & Capabilities > Push Notifications**. Also enable push updates when you start an activity in the demo. ActivityKit only issues a token when the app has this capability.
7. Build and run (**Cmd+R**).

### After changing web code

```bash
bun run build
bunx cap sync ios
python3 ios/configure-live-activities-target.py
```

Then run again from Xcode.

### Push token in the demo

When ActivityKit push updates are enabled for an activity, `getAllActivities()` may include a `pushToken` field (hex). The demo shows it on the **ActivityKit push token** card. You do not need an APNs backend to display that token. An APNs backend is only required to send server-driven Live Activity updates after you have the token (see the plugin getting started guide).

## Android

Timer sequence APIs work on Android. Generic `startActivity` Live Activities are iOS-only.

From the repository root:

```bash
bun install
bun run build
cd example-app
bun install
bun run build
bunx cap sync android
bunx cap open android
```

## Project layout

| Path | Purpose |
|------|---------|
| `src/main.js` | Demo UI calling the plugin API |
| `src/activityLayouts.js` | JSON layouts for the delivery sample |
| `ios/LiveActivities/` | Widget extension (`CapgoLiveActivityAttributes`) |
| `ios/configure-live-activities-target.py` | Idempotent Xcode target wiring (used in CI) |
