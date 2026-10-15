# @capgo/capacitor-live-activities demo

Capacitor example app for the local `@capgo/capacitor-live-activities` plugin (`file:..`). It includes a **LiveActivities** Widget Extension that uses `CapgoLiveActivityAttributes` and the shared JSON layout renderer from the plugin.

## What you can try

- **Start delivery**: starts a delivery-tracking Live Activity (lock screen and Dynamic Island on supported devices).
- **Update status**: advances the demo through preparing, on the way, arriving, and delivered.
- **End activity**: ends the Live Activity.
- **Refresh**: lists activities from `getAllActivities()` and shows the ActivityKit push token when available.
- **Plugin version**: reads the native plugin version.

## Prerequisites

- [Bun](https://bun.sh) (same as the parent repo)
- Xcode 15+ with iOS 16.1 SDK
- Physical iPhone or simulator on **iOS 16.1+** (Dynamic Island needs a supported device model)
- Live Activities enabled for the app in **Settings > (app name)**

## Run in the browser (web shell only)

```bash
bun install
bun run start
```

Live Activities APIs are unavailable on web; the UI still loads for layout checks.

## Run on iOS (device or simulator)

From this `example-app` folder:

```bash
bun install
bun run build
bunx cap sync ios
```

Open the workspace in Xcode:

```bash
bunx cap open ios
```

In Xcode:

1. Select the **App** scheme and your simulator or device.
2. Confirm **App** and **LiveActivitiesExtension** targets use deployment target **iOS 16.1+**.
3. Confirm App Groups `group.app.capgo.live.activities.liveactivities` on **App** and **LiveActivitiesExtension** (already set in the committed entitlements). If you change this id, update every copy together: App entitlements, LiveActivities entitlements, `CapgoLiveActivityWidget.swift` `appGroupIdentifier()`, and the plugin App Group in your host app.
4. Build and run (**Cmd+R**).

### After changing web code

```bash
bun run build
bunx cap sync ios
```

Then run again from Xcode.

### Push token in the demo

When ActivityKit push updates are enabled for an activity, `getAllActivities()` may include a `pushToken` field (hex). The demo shows it on the **ActivityKit push token** card. Server-driven updates also need Push Notifications capability and an APNs backend (see the plugin getting started guide).

## Android

Timer sequence APIs work on Android. Generic `startActivity` Live Activities are iOS-only.

```bash
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
