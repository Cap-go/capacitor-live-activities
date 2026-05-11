# @capgo/capacitor-live-activities
<a href="https://capgo.app/"><img src="https://capgo.app/readme-banner.svg?repo=Cap-go/capacitor-live-activities" alt="Capgo - Instant updates for Capacitor" /></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_live_activities"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_live_activities"> Missing a feature? We'll build the plugin for you 💪</a></h2>
</div>

Manage iOS Live Activities from Capacitor with a powerful JSON-based layout system.

## Why Capacitor Live Activities?

- **iOS 16.1+ Live Activities** - Full integration with Apple's Live Activities framework
- **Dynamic Island Support** - Seamless integration with iPhone 14 Pro+ Dynamic Island
- **JSON Layout System** - Build complex layouts declaratively without Swift code
- **Real-time Updates** - Update your activities dynamically from your app
- **Image Management** - Save and use images in your Live Activities via App Groups
- **Cross-platform Safe** - Graceful fallbacks on Android and web

Essential for delivery tracking apps, sports scores, ride-sharing, timers, and any app needing real-time lock screen updates.

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/live-activities/

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.\*.\*       | v8.\*.\*                | ✅          |
| v7.\*.\*       | v7.\*.\*                | On demand   |
| v6.\*.\*       | v6.\*.\*                | ❌          |
| v5.\*.\*       | v5.\*.\*                | ❌          |

> **Note:** The major version of this plugin follows the major version of Capacitor. Use the version that matches your Capacitor installation (e.g., plugin v8 for Capacitor 8). Only the latest major version is actively maintained.

## Install

```bash
bun add @capgo/capacitor-live-activities
bunx cap sync
```

## Requirements

- **iOS 16.1+** - Live Activities require iOS 16.1 or later
- **Widget Extension** - You must create a Widget Extension target in Xcode
- **App Groups** - Required for sharing data between app and widget

## iOS Setup

### 1. Create Widget Extension

In Xcode:
1. File → New → Target
2. Select "Widget Extension"
3. Name it exactly: `LiveActivities`
4. Uncheck "Include Configuration Intent"

### 2. Configure App Groups

1. Select your main app target → Signing & Capabilities
2. Add "App Groups" capability
3. Create group: `group.YOUR_BUNDLE_ID.liveactivities`
4. Add the same App Group to your Widget Extension target

### 3. Enable Live Activities in Info.plist

Add to your app's Info.plist:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### 4. Create the Widget Bundle

In your Widget Extension, create `LiveActivitiesBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct LiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        // Your Live Activity widget goes here
        LiveActivityWidget()
    }
}
```

## Usage Examples

### Check Support

```typescript
import { CapgoLiveActivities } from '@capgo/capacitor-live-activities';

const checkSupport = async () => {
  const { supported, reason } = await CapgoLiveActivities.areActivitiesSupported();
  if (supported) {
    console.log('Live Activities are supported!');
  } else {
    console.log('Not supported:', reason);
  }
};
```

### Start a Delivery Tracking Activity

```typescript
import { CapgoLiveActivities } from '@capgo/capacitor-live-activities';

const startDeliveryActivity = async () => {
  const { activityId } = await CapgoLiveActivities.startActivity({
    layout: {
      type: 'container',
      direction: 'vertical',
      spacing: 8,
      children: [
        {
          type: 'container',
          direction: 'horizontal',
          children: [
            { type: 'image', source: 'sfSymbol', value: 'box.truck.fill', width: 24, height: 24, tintColor: '#007AFF' },
            { type: 'text', content: 'Order #{{orderNumber}}', fontSize: 16, fontWeight: 'bold' }
          ]
        },
        { type: 'text', content: '{{status}}', fontSize: 14, color: '#666666' },
        { type: 'progress', value: 'progress', tint: '#34C759' }
      ]
    },
    dynamicIslandLayout: {
      expanded: {
        leading: { type: 'image', source: 'sfSymbol', value: 'box.truck.fill', tintColor: '#007AFF' },
        trailing: { type: 'text', content: '{{eta}}', fontWeight: 'semibold' },
        center: { type: 'text', content: '{{status}}', fontSize: 14 },
        bottom: { type: 'progress', value: 'progress', tint: '#34C759' }
      },
      compactLeading: { type: 'image', source: 'sfSymbol', value: 'box.truck.fill' },
      compactTrailing: { type: 'text', content: '{{eta}}' },
      minimal: { type: 'image', source: 'sfSymbol', value: 'box.truck.fill' }
    },
    behavior: {
      widgetUrl: 'myapp://order/12345'
    },
    data: {
      orderNumber: '12345',
      status: 'On the way',
      eta: '10 min',
      progress: 0.6
    }
  });

  console.log('Started activity:', activityId);
  return activityId;
};
```

### Update an Activity

```typescript
const updateActivity = async (activityId: string) => {
  await CapgoLiveActivities.updateActivity({
    activityId,
    data: {
      status: 'Arriving soon!',
      eta: '2 min',
      progress: 0.9
    },
    alertConfiguration: {
      title: 'Delivery Update',
      body: 'Your order is almost there!'
    }
  });
};
```

### End an Activity

```typescript
const endActivity = async (activityId: string) => {
  await CapgoLiveActivities.endActivity({
    activityId,
    data: {
      status: 'Delivered!',
      progress: 1.0
    },
    dismissalPolicy: 'after',
    dismissAfter: Date.now() + 3600000 // Keep visible for 1 hour
  });
};
```

### Timer Example (Countdown)

```typescript
const startTimerActivity = async () => {
  const targetDate = Date.now() + 1800000; // 30 minutes from now

  const { activityId } = await CapgoLiveActivities.startActivity({
    layout: {
      type: 'container',
      direction: 'horizontal',
      spacing: 16,
      children: [
        { type: 'image', source: 'sfSymbol', value: 'timer', width: 32, height: 32 },
        {
          type: 'container',
          direction: 'vertical',
          children: [
            { type: 'text', content: '{{title}}', fontSize: 16, fontWeight: 'bold' },
            { type: 'timer', targetDate: 'endTime', style: 'timer', fontSize: 24, fontWeight: 'bold', color: '#FF3B30' }
          ]
        }
      ]
    },
    dynamicIslandLayout: {
      expanded: {
        center: { type: 'text', content: '{{title}}' },
        bottom: { type: 'timer', targetDate: 'endTime', style: 'timer', fontSize: 32 }
      },
      compactLeading: { type: 'image', source: 'sfSymbol', value: 'timer' },
      compactTrailing: { type: 'timer', targetDate: 'endTime', style: 'timer' },
      minimal: { type: 'timer', targetDate: 'endTime', style: 'timer' }
    },
    data: {
      title: 'Cooking Timer',
      endTime: targetDate
    }
  });

  return activityId;
};
```

### Using Saved Images

```typescript
// Save an image first
const { imageName } = await CapgoLiveActivities.saveImage({
  imageData: 'base64EncodedImageData...',
  name: 'product-thumbnail',
  compressionQuality: 0.8
});

// Use in activity layout
const { activityId } = await CapgoLiveActivities.startActivity({
  layout: {
    type: 'container',
    direction: 'horizontal',
    children: [
      { type: 'image', source: 'saved', value: imageName, width: 48, height: 48, properties: { cornerRadius: 8 } },
      { type: 'text', content: '{{productName}}', fontSize: 16 }
    ]
  },
  // ... rest of config
});

// Cleanup when done
await CapgoLiveActivities.cleanupImages();
```

## Layout Elements

### Container
Groups child elements horizontally, vertically, or stacked.

```typescript
{
  type: 'container',
  direction: 'horizontal' | 'vertical' | 'zstack',
  alignment: 'leading' | 'center' | 'trailing' | 'top' | 'bottom',
  spacing: 8,
  children: [/* ... */],
  properties: { padding: 12, backgroundColor: '#F5F5F5', cornerRadius: 8 }
}
```

### Text
Displays text with styling and variable interpolation.

```typescript
{
  type: 'text',
  content: 'Hello {{name}}!',
  fontSize: 16,
  fontWeight: 'bold',
  color: '#000000',
  alignment: 'center',
  lineLimit: 2,
  fontDesign: 'rounded'
}
```

### Image
Displays images from various sources.

```typescript
// SF Symbol
{ type: 'image', source: 'sfSymbol', value: 'star.fill', tintColor: '#FFD700' }

// URL
{ type: 'image', source: 'url', value: 'https://example.com/image.png', width: 48, height: 48 }

// Saved image
{ type: 'image', source: 'saved', value: 'my-saved-image' }

// Asset from bundle
{ type: 'image', source: 'asset', value: 'logo' }
```

### Progress
Shows a progress bar.

```typescript
{
  type: 'progress',
  value: 'progressValue', // Key in data object (0-1)
  tint: '#34C759'
}
```

### Timer
Displays a countdown or elapsed time.

```typescript
{
  type: 'timer',
  targetDate: 'endTime', // Key in data object (timestamp)
  style: 'timer' | 'relative' | 'offset',
  fontSize: 24,
  color: '#FF3B30',
  pausesOnReach: true
}
```

### Gauge
Circular progress indicator.

```typescript
{
  type: 'gauge',
  value: 'level', // Key in data (0-1)
  style: 'accessoryCircular',
  label: 'Battery',
  tint: '#34C759'
}
```

### Spacer
Flexible space between elements.

```typescript
{ type: 'spacer', minLength: 8 }
```

## API

<docgen-index>

* [`areActivitiesSupported()`](#areactivitiessupported)
* [`startActivity(...)`](#startactivity)
* [`updateActivity(...)`](#updateactivity)
* [`endActivity(...)`](#endactivity)
* [`getAllActivities()`](#getallactivities)
* [`saveImage(...)`](#saveimage)
* [`removeImage(...)`](#removeimage)
* [`listImages()`](#listimages)
* [`cleanupImages()`](#cleanupimages)
* [`getPluginVersion()`](#getpluginversion)
* [`startTimerSequence(...)`](#starttimersequence)
* [`pauseTimerSequence(...)`](#pausetimersequence)
* [`resumeTimerSequence(...)`](#resumetimersequence)
* [`stopTimerSequence(...)`](#stoptimersequence)
* [`skipTimerStep(...)`](#skiptimerstep)
* [`previousTimerStep(...)`](#previoustimerstep)
* [`getTimerState(...)`](#gettimerstate)
* [`addListener('timerSequenceEvent', ...)`](#addlistenertimersequenceevent-)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

Capacitor Live Activities Plugin interface for managing iOS Live Activities.

### areActivitiesSupported()

```typescript
areActivitiesSupported() => Promise<AreActivitiesSupportedResult>
```

Check if Live Activities are supported on this device.
Requires iOS 16.1+ and device support.

**Returns:** <code>Promise&lt;<a href="#areactivitiessupportedresult">AreActivitiesSupportedResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### startActivity(...)

```typescript
startActivity(options: StartActivityOptions) => Promise<StartActivityResult>
```

Start a new Live Activity with the specified layout and data.

| Param         | Type                                                                  | Description                         |
| ------------- | --------------------------------------------------------------------- | ----------------------------------- |
| **`options`** | <code><a href="#startactivityoptions">StartActivityOptions</a></code> | - Options for starting the activity |

**Returns:** <code>Promise&lt;<a href="#startactivityresult">StartActivityResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### updateActivity(...)

```typescript
updateActivity(options: UpdateActivityOptions) => Promise<void>
```

Update an existing Live Activity with new data.

| Param         | Type                                                                    | Description                         |
| ------------- | ----------------------------------------------------------------------- | ----------------------------------- |
| **`options`** | <code><a href="#updateactivityoptions">UpdateActivityOptions</a></code> | - Options for updating the activity |

**Since:** 1.0.0

--------------------


### endActivity(...)

```typescript
endActivity(options: EndActivityOptions) => Promise<void>
```

End a Live Activity.

| Param         | Type                                                              | Description                       |
| ------------- | ----------------------------------------------------------------- | --------------------------------- |
| **`options`** | <code><a href="#endactivityoptions">EndActivityOptions</a></code> | - Options for ending the activity |

**Since:** 1.0.0

--------------------


### getAllActivities()

```typescript
getAllActivities() => Promise<GetAllActivitiesResult>
```

Get all currently active Live Activities.

**Returns:** <code>Promise&lt;<a href="#getallactivitiesresult">GetAllActivitiesResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### saveImage(...)

```typescript
saveImage(options: SaveImageOptions) => Promise<SaveImageResult>
```

Save an image to the shared App Group container for use in Live Activities.
Images must be saved to the shared container to be accessible from the widget extension.

| Param         | Type                                                          | Description                    |
| ------------- | ------------------------------------------------------------- | ------------------------------ |
| **`options`** | <code><a href="#saveimageoptions">SaveImageOptions</a></code> | - Options for saving the image |

**Returns:** <code>Promise&lt;<a href="#saveimageresult">SaveImageResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### removeImage(...)

```typescript
removeImage(options: RemoveImageOptions) => Promise<RemoveImageResult>
```

Remove a saved image from the shared container.

| Param         | Type                                                              | Description                      |
| ------------- | ----------------------------------------------------------------- | -------------------------------- |
| **`options`** | <code><a href="#removeimageoptions">RemoveImageOptions</a></code> | - Options for removing the image |

**Returns:** <code>Promise&lt;<a href="#removeimageresult">RemoveImageResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### listImages()

```typescript
listImages() => Promise<ListImagesResult>
```

List all saved images in the shared container.

**Returns:** <code>Promise&lt;<a href="#listimagesresult">ListImagesResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### cleanupImages()

```typescript
cleanupImages() => Promise<void>
```

Remove all saved images from the shared container.

**Since:** 1.0.0

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<{ version: string; }>
```

Get the native Capacitor plugin version.

**Returns:** <code>Promise&lt;{ version: string; }&gt;</code>

**Since:** 1.0.0

--------------------


### startTimerSequence(...)

```typescript
startTimerSequence(options: TimerSequenceOptions) => Promise<TimerSequenceResult>
```

Start a timer sequence for workouts/sports.
On iOS: Shows in Live Activity and Dynamic Island
On Android: Shows as a foreground notification with timer

| Param         | Type                                                                  | Description                    |
| ------------- | --------------------------------------------------------------------- | ------------------------------ |
| **`options`** | <code><a href="#timersequenceoptions">TimerSequenceOptions</a></code> | - Timer sequence configuration |

**Returns:** <code>Promise&lt;<a href="#timersequenceresult">TimerSequenceResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### pauseTimerSequence(...)

```typescript
pauseTimerSequence(options: { sequenceId: string; }) => Promise<void>
```

Pause the timer sequence.

| Param         | Type                                 | Description                          |
| ------------- | ------------------------------------ | ------------------------------------ |
| **`options`** | <code>{ sequenceId: string; }</code> | - Options containing the sequence ID |

**Since:** 1.0.0

--------------------


### resumeTimerSequence(...)

```typescript
resumeTimerSequence(options: { sequenceId: string; }) => Promise<void>
```

Resume a paused timer sequence.

| Param         | Type                                 | Description                          |
| ------------- | ------------------------------------ | ------------------------------------ |
| **`options`** | <code>{ sequenceId: string; }</code> | - Options containing the sequence ID |

**Since:** 1.0.0

--------------------


### stopTimerSequence(...)

```typescript
stopTimerSequence(options: { sequenceId: string; }) => Promise<void>
```

Stop and dismiss the timer sequence.

| Param         | Type                                 | Description                          |
| ------------- | ------------------------------------ | ------------------------------------ |
| **`options`** | <code>{ sequenceId: string; }</code> | - Options containing the sequence ID |

**Since:** 1.0.0

--------------------


### skipTimerStep(...)

```typescript
skipTimerStep(options: { sequenceId: string; }) => Promise<void>
```

Skip to the next step in the sequence.

| Param         | Type                                 | Description                          |
| ------------- | ------------------------------------ | ------------------------------------ |
| **`options`** | <code>{ sequenceId: string; }</code> | - Options containing the sequence ID |

**Since:** 1.0.0

--------------------


### previousTimerStep(...)

```typescript
previousTimerStep(options: { sequenceId: string; }) => Promise<void>
```

Go back to the previous step in the sequence.

| Param         | Type                                 | Description                          |
| ------------- | ------------------------------------ | ------------------------------------ |
| **`options`** | <code>{ sequenceId: string; }</code> | - Options containing the sequence ID |

**Since:** 1.0.0

--------------------


### getTimerState(...)

```typescript
getTimerState(options: GetTimerStateOptions) => Promise<TimerSequenceState>
```

Get the current state of a timer sequence.

| Param         | Type                                                                  | Description                          |
| ------------- | --------------------------------------------------------------------- | ------------------------------------ |
| **`options`** | <code><a href="#gettimerstateoptions">GetTimerStateOptions</a></code> | - Options containing the sequence ID |

**Returns:** <code>Promise&lt;<a href="#timersequencestate">TimerSequenceState</a>&gt;</code>

**Since:** 1.0.0

--------------------


### addListener('timerSequenceEvent', ...)

```typescript
addListener(eventName: 'timerSequenceEvent', callback: TimerSequenceCallback) => Promise<{ remove: () => Promise<void>; }>
```

Add a listener for timer sequence events.
Events include: stepChange, complete, tick, paused, resumed, stopped, loopComplete

| Param           | Type                                                                    | Description                                 |
| --------------- | ----------------------------------------------------------------------- | ------------------------------------------- |
| **`eventName`** | <code>'timerSequenceEvent'</code>                                       | - The event name to listen for              |
| **`callback`**  | <code><a href="#timersequencecallback">TimerSequenceCallback</a></code> | - Callback function that receives the event |

**Returns:** <code>Promise&lt;{ remove: () =&gt; Promise&lt;void&gt;; }&gt;</code>

**Since:** 1.0.0

--------------------


### Interfaces


#### AreActivitiesSupportedResult

Result of checking if activities are supported

| Prop            | Type                 | Description                                          |
| --------------- | -------------------- | ---------------------------------------------------- |
| **`supported`** | <code>boolean</code> | Whether Live Activities are supported on this device |
| **`reason`**    | <code>string</code>  | Reason if not supported                              |


#### StartActivityResult

Result of starting an activity

| Prop             | Type                | Description                |
| ---------------- | ------------------- | -------------------------- |
| **`activityId`** | <code>string</code> | Unique activity identifier |


#### StartActivityOptions

Options for starting a Live Activity

| Prop                      | Type                                                                      | Description                                              |
| ------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------- |
| **`layout`**              | <code><a href="#activitylayout">ActivityLayout</a></code>                 | Main activity layout (lock screen widget)                |
| **`dynamicIslandLayout`** | <code><a href="#dynamicislandlayout">DynamicIslandLayout</a></code>       | Dynamic Island layout configuration                      |
| **`behavior`**            | <code><a href="#liveactivitiesbehavior">LiveActivitiesBehavior</a></code> | Activity behavior settings                               |
| **`data`**                | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code>          | Dynamic data for the activity                            |
| **`staleDate`**           | <code>number</code>                                                       | Stale date timestamp (activity becomes stale after this) |
| **`relevanceScore`**      | <code>number</code>                                                       | Relevance score for activity ordering (0-100)            |


#### LayoutElementContainer

Container layout element for grouping child elements

| Prop             | Type                                                                  | Description                |
| ---------------- | --------------------------------------------------------------------- | -------------------------- |
| **`type`**       | <code>'container'</code>                                              |                            |
| **`direction`**  | <code>'horizontal' \| 'vertical' \| 'zstack'</code>                   | Layout direction           |
| **`children`**   | <code>LayoutElement[]</code>                                          | Child elements             |
| **`alignment`**  | <code>'leading' \| 'center' \| 'trailing' \| 'top' \| 'bottom'</code> | Alignment within container |
| **`spacing`**    | <code>number</code>                                                   | Spacing between children   |
| **`properties`** | <code><a href="#baselayoutproperties">BaseLayoutProperties</a></code> | Container properties       |


#### BaseLayoutProperties

Base layout element properties

| Prop                  | Type                                                                                           | Description                |
| --------------------- | ---------------------------------------------------------------------------------------------- | -------------------------- |
| **`padding`**         | <code>number \| { top?: number; bottom?: number; leading?: number; trailing?: number; }</code> | Padding around the element |
| **`backgroundColor`** | <code><a href="#colorstring">ColorString</a></code>                                            | Background color           |
| **`cornerRadius`**    | <code>number</code>                                                                            | Corner radius              |
| **`width`**           | <code>number \| 'infinity'</code>                                                              | Frame width                |
| **`height`**          | <code>number</code>                                                                            | Frame height               |
| **`opacity`**         | <code>number</code>                                                                            | Opacity (0-1)              |


#### LayoutElementText

Text layout element

| Prop             | Type                                                                                                                  | Description                                        |
| ---------------- | --------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| **`type`**       | <code>'text'</code>                                                                                                   |                                                    |
| **`content`**    | <code>string</code>                                                                                                   | Text content - supports {{variable}} interpolation |
| **`fontSize`**   | <code>number</code>                                                                                                   | Font size                                          |
| **`fontWeight`** | <code>'ultraLight' \| 'thin' \| 'light' \| 'regular' \| 'medium' \| 'semibold' \| 'bold' \| 'heavy' \| 'black'</code> | Font weight                                        |
| **`color`**      | <code><a href="#colorstring">ColorString</a></code>                                                                   | Text color                                         |
| **`alignment`**  | <code>'leading' \| 'center' \| 'trailing'</code>                                                                      | Text alignment                                     |
| **`lineLimit`**  | <code>number</code>                                                                                                   | Line limit                                         |
| **`fontDesign`** | <code>'default' \| 'monospaced' \| 'rounded' \| 'serif'</code>                                                        | Font design                                        |
| **`properties`** | <code><a href="#baselayoutproperties">BaseLayoutProperties</a></code>                                                 | Element properties                                 |


#### LayoutElementImage

Image layout element

| Prop              | Type                                                                  | Description                                                                    |
| ----------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **`type`**        | <code>'image'</code>                                                  |                                                                                |
| **`source`**      | <code>'url' \| 'sfSymbol' \| 'asset' \| 'base64' \| 'saved'</code>    | Image source type                                                              |
| **`value`**       | <code>string</code>                                                   | Image value (URL, symbol name, asset name, base64 string, or saved image name) |
| **`width`**       | <code>number</code>                                                   | Image width                                                                    |
| **`height`**      | <code>number</code>                                                   | Image height                                                                   |
| **`contentMode`** | <code>'fit' \| 'fill'</code>                                          | Content mode                                                                   |
| **`tintColor`**   | <code><a href="#colorstring">ColorString</a></code>                   | Tint color for SF Symbols                                                      |
| **`properties`**  | <code><a href="#baselayoutproperties">BaseLayoutProperties</a></code> | Element properties                                                             |


#### LayoutElementProgress

Progress bar layout element

| Prop             | Type                                                                  | Description                                      |
| ---------------- | --------------------------------------------------------------------- | ------------------------------------------------ |
| **`type`**       | <code>'progress'</code>                                               |                                                  |
| **`value`**      | <code>string \| number</code>                                         | Progress value key in data (0-1) or direct value |
| **`total`**      | <code>string \| number</code>                                         | Total value key in data or direct value          |
| **`tint`**       | <code><a href="#colorstring">ColorString</a></code>                   | Progress bar color                               |
| **`properties`** | <code><a href="#baselayoutproperties">BaseLayoutProperties</a></code> | Element properties                               |


#### LayoutElementTimer

Timer layout element for countdowns

| Prop                | Type                                                                                                                  | Description                          |
| ------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| **`type`**          | <code>'timer'</code>                                                                                                  |                                      |
| **`targetDate`**    | <code>string \| number</code>                                                                                         | Target date key in data or timestamp |
| **`style`**         | <code>'timer' \| 'relative' \| 'offset'</code>                                                                        | Timer style                          |
| **`pausesOnReach`** | <code>boolean</code>                                                                                                  | Pause when target reached            |
| **`fontSize`**      | <code>number</code>                                                                                                   | Font size                            |
| **`color`**         | <code><a href="#colorstring">ColorString</a></code>                                                                   | Text color                           |
| **`fontWeight`**    | <code>'ultraLight' \| 'thin' \| 'light' \| 'regular' \| 'medium' \| 'semibold' \| 'bold' \| 'heavy' \| 'black'</code> | Font weight                          |
| **`properties`**    | <code><a href="#baselayoutproperties">BaseLayoutProperties</a></code>                                                 | Element properties                   |


#### LayoutElementSpacer

Spacer layout element

| Prop            | Type                  | Description    |
| --------------- | --------------------- | -------------- |
| **`type`**      | <code>'spacer'</code> |                |
| **`minLength`** | <code>number</code>   | Minimum length |


#### LayoutElementGauge

Gauge layout element for circular progress

| Prop                    | Type                                                                                               | Description                                     |
| ----------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| **`type`**              | <code>'gauge'</code>                                                                               |                                                 |
| **`value`**             | <code>string \| number</code>                                                                      | Current value key in data or direct value (0-1) |
| **`style`**             | <code>'automatic' \| 'accessoryCircular' \| 'accessoryCircularCapacity' \| 'linearCapacity'</code> | Gauge style                                     |
| **`label`**             | <code>string</code>                                                                                | Label text                                      |
| **`currentValueLabel`** | <code>string</code>                                                                                | Current value label                             |
| **`minimumValueLabel`** | <code>string</code>                                                                                | Minimum value label                             |
| **`maximumValueLabel`** | <code>string</code>                                                                                | Maximum value label                             |
| **`tint`**              | <code><a href="#colorstring">ColorString</a></code>                                                | Tint color                                      |
| **`properties`**        | <code><a href="#baselayoutproperties">BaseLayoutProperties</a></code>                              | Element properties                              |


#### DynamicIslandLayout

Dynamic Island layout configuration

| Prop                  | Type                                                                                | Description                  |
| --------------------- | ----------------------------------------------------------------------------------- | ---------------------------- |
| **`expanded`**        | <code><a href="#dynamicislandexpandedlayout">DynamicIslandExpandedLayout</a></code> | Expanded state layout        |
| **`compactLeading`**  | <code><a href="#layoutelement">LayoutElement</a></code>                             | Compact leading content      |
| **`compactTrailing`** | <code><a href="#layoutelement">LayoutElement</a></code>                             | Compact trailing content     |
| **`minimal`**         | <code><a href="#layoutelement">LayoutElement</a></code>                             | Minimal presentation content |


#### DynamicIslandExpandedLayout

Dynamic Island expanded layout configuration

| Prop           | Type                                                    | Description             |
| -------------- | ------------------------------------------------------- | ----------------------- |
| **`leading`**  | <code><a href="#layoutelement">LayoutElement</a></code> | Leading region content  |
| **`trailing`** | <code><a href="#layoutelement">LayoutElement</a></code> | Trailing region content |
| **`center`**   | <code><a href="#layoutelement">LayoutElement</a></code> | Center region content   |
| **`bottom`**   | <code><a href="#layoutelement">LayoutElement</a></code> | Bottom region content   |


#### LiveActivitiesBehavior

Live Activity behavior configuration

| Prop                              | Type                                                | Description                    |
| --------------------------------- | --------------------------------------------------- | ------------------------------ |
| **`widgetUrl`**                   | <code>string</code>                                 | Widget URL for deep linking    |
| **`backgroundTint`**              | <code><a href="#colorstring">ColorString</a></code> | Background tint color          |
| **`systemActionForegroundColor`** | <code><a href="#colorstring">ColorString</a></code> | System action foreground color |
| **`keyLineTint`**                 | <code><a href="#colorstring">ColorString</a></code> | Key line tint color            |


#### UpdateActivityOptions

Options for updating a Live Activity

| Prop                     | Type                                                                              | Description                        |
| ------------------------ | --------------------------------------------------------------------------------- | ---------------------------------- |
| **`activityId`**         | <code>string</code>                                                               | Activity ID to update              |
| **`data`**               | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code>                  | Updated data                       |
| **`alertConfiguration`** | <code><a href="#activityalertconfiguration">ActivityAlertConfiguration</a></code> | Optional alert to show with update |
| **`staleDate`**          | <code>number</code>                                                               | Updated stale date                 |
| **`relevanceScore`**     | <code>number</code>                                                               | Updated relevance score            |


#### ActivityAlertConfiguration

Alert configuration for activity updates

| Prop        | Type                | Description           |
| ----------- | ------------------- | --------------------- |
| **`title`** | <code>string</code> | Alert title           |
| **`body`**  | <code>string</code> | Alert body            |
| **`sound`** | <code>string</code> | Sound name (optional) |


#### EndActivityOptions

Options for ending a Live Activity

| Prop                  | Type                                                             | Description                                               |
| --------------------- | ---------------------------------------------------------------- | --------------------------------------------------------- |
| **`activityId`**      | <code>string</code>                                              | Activity ID to end                                        |
| **`data`**            | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code> | Final data to display                                     |
| **`dismissalPolicy`** | <code>'default' \| 'immediate' \| 'after'</code>                 | Dismissal policy                                          |
| **`dismissAfter`**    | <code>number</code>                                              | Dismiss after timestamp (when dismissalPolicy is 'after') |


#### GetAllActivitiesResult

Result of getAllActivities

| Prop             | Type                        | Description        |
| ---------------- | --------------------------- | ------------------ |
| **`activities`** | <code>ActivityInfo[]</code> | List of activities |


#### ActivityInfo

Activity info returned from getAllActivities

| Prop             | Type                                                             | Description            |
| ---------------- | ---------------------------------------------------------------- | ---------------------- |
| **`activityId`** | <code>string</code>                                              | Activity ID            |
| **`state`**      | <code>'active' \| 'ended' \| 'dismissed' \| 'stale'</code>       | Current activity state |
| **`startDate`**  | <code>number</code>                                              | Activity start date    |
| **`data`**       | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code> | Current data           |


#### SaveImageResult

Result of saving an image

| Prop            | Type                 | Description                     |
| --------------- | -------------------- | ------------------------------- |
| **`success`**   | <code>boolean</code> | Whether the save was successful |
| **`imageName`** | <code>string</code>  | Saved image name                |


#### SaveImageOptions

Options for saving an image

| Prop                     | Type                | Description                                 |
| ------------------------ | ------------------- | ------------------------------------------- |
| **`imageData`**          | <code>string</code> | Base64 encoded image data                   |
| **`name`**               | <code>string</code> | Name to save the image as                   |
| **`compressionQuality`** | <code>number</code> | JPEG compression quality (0-1, default 0.8) |


#### RemoveImageResult

Result of removing an image

| Prop          | Type                 | Description                        |
| ------------- | -------------------- | ---------------------------------- |
| **`success`** | <code>boolean</code> | Whether the removal was successful |


#### RemoveImageOptions

Options for removing an image

| Prop       | Type                | Description                 |
| ---------- | ------------------- | --------------------------- |
| **`name`** | <code>string</code> | Name of the image to remove |


#### ListImagesResult

Result of listing images

| Prop         | Type                  | Description               |
| ------------ | --------------------- | ------------------------- |
| **`images`** | <code>string[]</code> | List of saved image names |


#### TimerSequenceResult

Result of starting a timer sequence

| Prop             | Type                | Description                |
| ---------------- | ------------------- | -------------------------- |
| **`sequenceId`** | <code>string</code> | Unique sequence identifier |


#### TimerSequenceOptions

Options for starting a timer sequence

| Prop                 | Type                     | Description                                                     |
| -------------------- | ------------------------ | --------------------------------------------------------------- |
| **`steps`**          | <code>TimerStep[]</code> | Array of steps in the sequence                                  |
| **`title`**          | <code>string</code>      | Overall title for the sequence (e.g., "HIIT Workout", "Tabata") |
| **`loop`**           | <code>boolean</code>     | Whether to loop the sequence when complete                      |
| **`loopCount`**      | <code>number</code>      | Number of times to loop (if loop is true, 0 means infinite)     |
| **`soundEnabled`**   | <code>boolean</code>     | Play sound on step change (default: true)                       |
| **`vibrateEnabled`** | <code>boolean</code>     | Vibrate on step change (default: true)                          |
| **`countdownBeeps`** | <code>boolean</code>     | Play countdown beeps in last 3 seconds (default: true)          |
| **`tapUrl`**         | <code>string</code>      | Deep link URL when tapping the notification/activity            |
| **`keepScreenOn`**   | <code>boolean</code>     | Keep screen on during timer (Android only, default: false)      |


#### TimerStep

A single step in a timer sequence (e.g., workout interval)

| Prop           | Type                                                                | Description                                                                   |
| -------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **`duration`** | <code>number</code>                                                 | Duration of this step in seconds                                              |
| **`title`**    | <code>string</code>                                                 | Title/instruction for this step (e.g., "Push-ups", "Rest")                    |
| **`subtitle`** | <code>string</code>                                                 | Optional subtitle (e.g., "20 reps", "High intensity")                         |
| **`color`**    | <code>string</code>                                                 | Color for this step (hex color, e.g., "#FF0000" for work, "#00FF00" for rest) |
| **`icon`**     | <code>string</code>                                                 | Optional icon (SF Symbol name on iOS, material icon name on Android)          |
| **`sound`**    | <code>'beep' \| 'bell' \| 'whistle' \| 'countdown' \| 'none'</code> | Optional sound to play when step starts                                       |


#### TimerSequenceState

Current state of a timer sequence

| Prop                        | Type                                            | Description                                  |
| --------------------------- | ----------------------------------------------- | -------------------------------------------- |
| **`sequenceId`**            | <code>string</code>                             | Sequence ID                                  |
| **`isRunning`**             | <code>boolean</code>                            | Whether the sequence is running              |
| **`isPaused`**              | <code>boolean</code>                            | Whether the sequence is paused               |
| **`isComplete`**            | <code>boolean</code>                            | Whether the sequence is complete             |
| **`currentStepIndex`**      | <code>number</code>                             | Current step index (0-based)                 |
| **`totalSteps`**            | <code>number</code>                             | Total number of steps                        |
| **`currentStep`**           | <code><a href="#timerstep">TimerStep</a></code> | Current step info                            |
| **`remainingSeconds`**      | <code>number</code>                             | Remaining seconds in current step            |
| **`totalRemainingSeconds`** | <code>number</code>                             | Total remaining seconds for entire sequence  |
| **`elapsedSeconds`**        | <code>number</code>                             | Total elapsed seconds                        |
| **`currentLoop`**           | <code>number</code>                             | Current loop iteration (1-based, if looping) |
| **`totalLoops`**            | <code>number</code>                             | Total loops (0 if infinite or not looping)   |


#### GetTimerStateOptions

Options for getting timer state

| Prop             | Type                | Description                  |
| ---------------- | ------------------- | ---------------------------- |
| **`sequenceId`** | <code>string</code> | Sequence ID to get state for |


#### TimerSequenceEvent

Event data for timer sequence events

| Prop             | Type                                                                                                      | Description                       |
| ---------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **`type`**       | <code>'stepChange' \| 'complete' \| 'tick' \| 'paused' \| 'resumed' \| 'stopped' \| 'loopComplete'</code> | Event type                        |
| **`sequenceId`** | <code>string</code>                                                                                       | Sequence ID                       |
| **`state`**      | <code><a href="#timersequencestate">TimerSequenceState</a></code>                                         | Current state when event occurred |


### Type Aliases


#### ActivityLayout

Layout for the main activity view (lock screen widget)

<code><a href="#layoutelement">LayoutElement</a></code>


#### LayoutElement

Union type for all layout elements

<code><a href="#layoutelementcontainer">LayoutElementContainer</a> | <a href="#layoutelementtext">LayoutElementText</a> | <a href="#layoutelementimage">LayoutElementImage</a> | <a href="#layoutelementprogress">LayoutElementProgress</a> | <a href="#layoutelementtimer">LayoutElementTimer</a> | <a href="#layoutelementspacer">LayoutElementSpacer</a> | <a href="#layoutelementgauge">LayoutElementGauge</a></code>


#### ColorString

Color string type - supports hex colors and system colors

<code>string</code>


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>


#### TimerSequenceCallback

Callback type for timer sequence events

<code>(event: <a href="#timersequenceevent">TimerSequenceEvent</a>): void</code>

</docgen-api>

## Credits

Inspired by [ludufre/capacitor-live-activities](https://github.com/ludufre/capacitor-live-activities) with a simplified API and Capgo integration.
