/**
 * Color string type - supports hex colors and system colors
 *
 * @since 1.0.0
 */
export type ColorString = string;

/**
 * Layout element types supported in Live Activities
 *
 * @since 1.0.0
 */
export type LayoutElementType =
  | 'container'
  | 'text'
  | 'image'
  | 'progress'
  | 'timer'
  | 'spacer'
  | 'gauge';

/**
 * Base layout element properties
 *
 * @since 1.0.0
 */
export interface BaseLayoutProperties {
  /** Padding around the element */
  padding?: number | { top?: number; bottom?: number; leading?: number; trailing?: number };
  /** Background color */
  backgroundColor?: ColorString;
  /** Corner radius */
  cornerRadius?: number;
  /** Frame width */
  width?: number | 'infinity';
  /** Frame height */
  height?: number;
  /** Opacity (0-1) */
  opacity?: number;
}

/**
 * Container layout element for grouping child elements
 *
 * @since 1.0.0
 */
export interface LayoutElementContainer {
  type: 'container';
  /** Layout direction */
  direction?: 'horizontal' | 'vertical' | 'zstack';
  /** Child elements */
  children: LayoutElement[];
  /** Alignment within container */
  alignment?: 'leading' | 'center' | 'trailing' | 'top' | 'bottom';
  /** Spacing between children */
  spacing?: number;
  /** Container properties */
  properties?: BaseLayoutProperties;
}

/**
 * Text layout element
 *
 * @since 1.0.0
 */
export interface LayoutElementText {
  type: 'text';
  /** Text content - supports {{variable}} interpolation */
  content: string;
  /** Font size */
  fontSize?: number;
  /** Font weight */
  fontWeight?: 'ultraLight' | 'thin' | 'light' | 'regular' | 'medium' | 'semibold' | 'bold' | 'heavy' | 'black';
  /** Text color */
  color?: ColorString;
  /** Text alignment */
  alignment?: 'leading' | 'center' | 'trailing';
  /** Line limit */
  lineLimit?: number;
  /** Font design */
  fontDesign?: 'default' | 'monospaced' | 'rounded' | 'serif';
  /** Element properties */
  properties?: BaseLayoutProperties;
}

/**
 * Image layout element
 *
 * @since 1.0.0
 */
export interface LayoutElementImage {
  type: 'image';
  /** Image source type */
  source: 'url' | 'sfSymbol' | 'asset' | 'base64' | 'saved';
  /** Image value (URL, symbol name, asset name, base64 string, or saved image name) */
  value: string;
  /** Image width */
  width?: number;
  /** Image height */
  height?: number;
  /** Content mode */
  contentMode?: 'fit' | 'fill';
  /** Tint color for SF Symbols */
  tintColor?: ColorString;
  /** Element properties */
  properties?: BaseLayoutProperties;
}

/**
 * Progress bar layout element
 *
 * @since 1.0.0
 */
export interface LayoutElementProgress {
  type: 'progress';
  /** Progress value key in data (0-1) or direct value */
  value: string | number;
  /** Total value key in data or direct value */
  total?: string | number;
  /** Progress bar color */
  tint?: ColorString;
  /** Element properties */
  properties?: BaseLayoutProperties;
}

/**
 * Timer layout element for countdowns
 *
 * @since 1.0.0
 */
export interface LayoutElementTimer {
  type: 'timer';
  /** Target date key in data or timestamp */
  targetDate: string | number;
  /** Timer style */
  style?: 'timer' | 'relative' | 'offset';
  /** Pause when target reached */
  pausesOnReach?: boolean;
  /** Font size */
  fontSize?: number;
  /** Text color */
  color?: ColorString;
  /** Font weight */
  fontWeight?: 'ultraLight' | 'thin' | 'light' | 'regular' | 'medium' | 'semibold' | 'bold' | 'heavy' | 'black';
  /** Element properties */
  properties?: BaseLayoutProperties;
}

/**
 * Spacer layout element
 *
 * @since 1.0.0
 */
export interface LayoutElementSpacer {
  type: 'spacer';
  /** Minimum length */
  minLength?: number;
}

/**
 * Gauge layout element for circular progress
 *
 * @since 1.0.0
 */
export interface LayoutElementGauge {
  type: 'gauge';
  /** Current value key in data or direct value (0-1) */
  value: string | number;
  /** Gauge style */
  style?: 'automatic' | 'accessoryCircular' | 'accessoryCircularCapacity' | 'linearCapacity';
  /** Label text */
  label?: string;
  /** Current value label */
  currentValueLabel?: string;
  /** Minimum value label */
  minimumValueLabel?: string;
  /** Maximum value label */
  maximumValueLabel?: string;
  /** Tint color */
  tint?: ColorString;
  /** Element properties */
  properties?: BaseLayoutProperties;
}

/**
 * Union type for all layout elements
 *
 * @since 1.0.0
 */
export type LayoutElement =
  | LayoutElementContainer
  | LayoutElementText
  | LayoutElementImage
  | LayoutElementProgress
  | LayoutElementTimer
  | LayoutElementSpacer
  | LayoutElementGauge;

/**
 * Layout for the main activity view (lock screen widget)
 *
 * @since 1.0.0
 */
export type ActivityLayout = LayoutElement;

/**
 * Dynamic Island expanded layout configuration
 *
 * @since 1.0.0
 */
export interface DynamicIslandExpandedLayout {
  /** Leading region content */
  leading?: LayoutElement;
  /** Trailing region content */
  trailing?: LayoutElement;
  /** Center region content */
  center?: LayoutElement;
  /** Bottom region content */
  bottom?: LayoutElement;
}

/**
 * Dynamic Island layout configuration
 *
 * @since 1.0.0
 */
export interface DynamicIslandLayout {
  /** Expanded state layout */
  expanded: DynamicIslandExpandedLayout;
  /** Compact leading content */
  compactLeading: LayoutElement;
  /** Compact trailing content */
  compactTrailing: LayoutElement;
  /** Minimal presentation content */
  minimal: LayoutElement;
}

/**
 * Live Activity behavior configuration
 *
 * @since 1.0.0
 */
export interface LiveActivitiesBehavior {
  /** Widget URL for deep linking */
  widgetUrl?: string;
  /** Background tint color */
  backgroundTint?: ColorString;
  /** System action foreground color */
  systemActionForegroundColor?: ColorString;
  /** Key line tint color */
  keyLineTint?: ColorString;
}

/**
 * Options for starting a Live Activity
 *
 * @since 1.0.0
 */
export interface StartActivityOptions {
  /** Main activity layout (lock screen widget) */
  layout: ActivityLayout;
  /** Dynamic Island layout configuration */
  dynamicIslandLayout: DynamicIslandLayout;
  /** Activity behavior settings */
  behavior?: LiveActivitiesBehavior;
  /** Dynamic data for the activity */
  data: Record<string, unknown>;
  /** Stale date timestamp (activity becomes stale after this) */
  staleDate?: number;
  /** Relevance score for activity ordering (0-100) */
  relevanceScore?: number;
}

/**
 * Result of starting an activity
 *
 * @since 1.0.0
 */
export interface StartActivityResult {
  /** Unique activity identifier */
  activityId: string;
}

/**
 * Alert configuration for activity updates
 *
 * @since 1.0.0
 */
export interface ActivityAlertConfiguration {
  /** Alert title */
  title: string;
  /** Alert body */
  body: string;
  /** Sound name (optional) */
  sound?: string;
}

/**
 * Options for updating a Live Activity
 *
 * @since 1.0.0
 */
export interface UpdateActivityOptions {
  /** Activity ID to update */
  activityId: string;
  /** Updated data */
  data: Record<string, unknown>;
  /** Optional alert to show with update */
  alertConfiguration?: ActivityAlertConfiguration;
  /** Updated stale date */
  staleDate?: number;
  /** Updated relevance score */
  relevanceScore?: number;
}

/**
 * Options for ending a Live Activity
 *
 * @since 1.0.0
 */
export interface EndActivityOptions {
  /** Activity ID to end */
  activityId: string;
  /** Final data to display */
  data?: Record<string, unknown>;
  /** Dismissal policy */
  dismissalPolicy?: 'immediate' | 'default' | 'after';
  /** Dismiss after timestamp (when dismissalPolicy is 'after') */
  dismissAfter?: number;
}

/**
 * Activity info returned from getAllActivities
 *
 * @since 1.0.0
 */
export interface ActivityInfo {
  /** Activity ID */
  activityId: string;
  /** Current activity state */
  state: 'active' | 'ended' | 'dismissed' | 'stale';
  /** Activity start date */
  startDate: number;
  /** Current data */
  data: Record<string, unknown>;
}

/**
 * Result of getAllActivities
 *
 * @since 1.0.0
 */
export interface GetAllActivitiesResult {
  /** List of activities */
  activities: ActivityInfo[];
}

/**
 * Options for saving an image
 *
 * @since 1.0.0
 */
export interface SaveImageOptions {
  /** Base64 encoded image data */
  imageData: string;
  /** Name to save the image as */
  name: string;
  /** JPEG compression quality (0-1, default 0.8) */
  compressionQuality?: number;
}

/**
 * Result of saving an image
 *
 * @since 1.0.0
 */
export interface SaveImageResult {
  /** Whether the save was successful */
  success: boolean;
  /** Saved image name */
  imageName: string;
}

/**
 * Options for removing an image
 *
 * @since 1.0.0
 */
export interface RemoveImageOptions {
  /** Name of the image to remove */
  name: string;
}

/**
 * Result of removing an image
 *
 * @since 1.0.0
 */
export interface RemoveImageResult {
  /** Whether the removal was successful */
  success: boolean;
}

/**
 * Result of listing images
 *
 * @since 1.0.0
 */
export interface ListImagesResult {
  /** List of saved image names */
  images: string[];
}

/**
 * Result of checking if activities are supported
 *
 * @since 1.0.0
 */
export interface AreActivitiesSupportedResult {
  /** Whether Live Activities are supported on this device */
  supported: boolean;
  /** Reason if not supported */
  reason?: string;
}

// ============================================================================
// TIMER SEQUENCE TYPES (for workout/sport timers)
// ============================================================================

/**
 * A single step in a timer sequence (e.g., workout interval)
 *
 * @since 1.0.0
 */
export interface TimerStep {
  /** Duration of this step in seconds */
  duration: number;
  /** Title/instruction for this step (e.g., "Push-ups", "Rest") */
  title: string;
  /** Optional subtitle (e.g., "20 reps", "High intensity") */
  subtitle?: string;
  /** Color for this step (hex color, e.g., "#FF0000" for work, "#00FF00" for rest) */
  color?: string;
  /** Optional icon (SF Symbol name on iOS, material icon name on Android) */
  icon?: string;
  /** Optional sound to play when step starts */
  sound?: 'beep' | 'bell' | 'whistle' | 'countdown' | 'none';
}

/**
 * Options for starting a timer sequence
 *
 * @since 1.0.0
 */
export interface TimerSequenceOptions {
  /** Array of steps in the sequence */
  steps: TimerStep[];
  /** Overall title for the sequence (e.g., "HIIT Workout", "Tabata") */
  title?: string;
  /** Whether to loop the sequence when complete */
  loop?: boolean;
  /** Number of times to loop (if loop is true, 0 means infinite) */
  loopCount?: number;
  /** Play sound on step change (default: true) */
  soundEnabled?: boolean;
  /** Vibrate on step change (default: true) */
  vibrateEnabled?: boolean;
  /** Play countdown beeps in last 3 seconds (default: true) */
  countdownBeeps?: boolean;
  /** Deep link URL when tapping the notification/activity */
  tapUrl?: string;
  /** Keep screen on during timer (Android only, default: false) */
  keepScreenOn?: boolean;
}

/**
 * Result of starting a timer sequence
 *
 * @since 1.0.0
 */
export interface TimerSequenceResult {
  /** Unique sequence identifier */
  sequenceId: string;
}

/**
 * Current state of a timer sequence
 *
 * @since 1.0.0
 */
export interface TimerSequenceState {
  /** Sequence ID */
  sequenceId: string;
  /** Whether the sequence is running */
  isRunning: boolean;
  /** Whether the sequence is paused */
  isPaused: boolean;
  /** Whether the sequence is complete */
  isComplete: boolean;
  /** Current step index (0-based) */
  currentStepIndex: number;
  /** Total number of steps */
  totalSteps: number;
  /** Current step info */
  currentStep: TimerStep;
  /** Remaining seconds in current step */
  remainingSeconds: number;
  /** Total remaining seconds for entire sequence */
  totalRemainingSeconds: number;
  /** Total elapsed seconds */
  elapsedSeconds: number;
  /** Current loop iteration (1-based, if looping) */
  currentLoop: number;
  /** Total loops (0 if infinite or not looping) */
  totalLoops: number;
}

/**
 * Event data for timer sequence events
 *
 * @since 1.0.0
 */
export interface TimerSequenceEvent {
  /** Event type */
  type: 'stepChange' | 'complete' | 'tick' | 'paused' | 'resumed' | 'stopped' | 'loopComplete';
  /** Sequence ID */
  sequenceId: string;
  /** Current state when event occurred */
  state: TimerSequenceState;
}

/**
 * Callback type for timer sequence events
 *
 * @since 1.0.0
 */
export type TimerSequenceCallback = (event: TimerSequenceEvent) => void;

/**
 * Options for getting timer state
 *
 * @since 1.0.0
 */
export interface GetTimerStateOptions {
  /** Sequence ID to get state for */
  sequenceId: string;
}

/**
 * Capacitor Live Activities Plugin interface for managing iOS Live Activities.
 *
 * @since 1.0.0
 */
export interface CapgoLiveActivitiesPlugin {
  /**
   * Check if Live Activities are supported on this device.
   * Requires iOS 16.1+ and device support.
   *
   * @returns Promise that resolves with support status
   * @since 1.0.0
   * @example
   * ```typescript
   * const { supported, reason } = await CapgoLiveActivities.areActivitiesSupported();
   * if (supported) {
   *   console.log('Live Activities are supported!');
   * } else {
   *   console.log('Not supported:', reason);
   * }
   * ```
   */
  areActivitiesSupported(): Promise<AreActivitiesSupportedResult>;

  /**
   * Start a new Live Activity with the specified layout and data.
   *
   * @param options - Options for starting the activity
   * @returns Promise that resolves with the activity ID
   * @throws Error if activity creation fails
   * @since 1.0.0
   * @example
   * ```typescript
   * const { activityId } = await CapgoLiveActivities.startActivity({
   *   layout: {
   *     type: 'container',
   *     direction: 'horizontal',
   *     children: [
   *       { type: 'text', content: 'Order #{{orderNumber}}', fontSize: 16, fontWeight: 'bold' },
   *       { type: 'text', content: '{{status}}', fontSize: 14, color: '#666666' }
   *     ]
   *   },
   *   dynamicIslandLayout: {
   *     expanded: {
   *       leading: { type: 'image', source: 'sfSymbol', value: 'box.truck' },
   *       trailing: { type: 'text', content: '{{eta}}' },
   *       center: { type: 'text', content: '{{status}}' },
   *       bottom: { type: 'progress', value: 'progress' }
   *     },
   *     compactLeading: { type: 'image', source: 'sfSymbol', value: 'box.truck' },
   *     compactTrailing: { type: 'text', content: '{{eta}}' },
   *     minimal: { type: 'image', source: 'sfSymbol', value: 'box.truck' }
   *   },
   *   data: {
   *     orderNumber: '12345',
   *     status: 'On the way',
   *     eta: '10 min',
   *     progress: 0.6
   *   }
   * });
   * console.log('Started activity:', activityId);
   * ```
   */
  startActivity(options: StartActivityOptions): Promise<StartActivityResult>;

  /**
   * Update an existing Live Activity with new data.
   *
   * @param options - Options for updating the activity
   * @returns Promise that resolves when update is complete
   * @throws Error if activity not found or update fails
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.updateActivity({
   *   activityId: 'abc123',
   *   data: {
   *     status: 'Arrived!',
   *     eta: 'Now',
   *     progress: 1.0
   *   },
   *   alertConfiguration: {
   *     title: 'Delivery Update',
   *     body: 'Your order has arrived!'
   *   }
   * });
   * ```
   */
  updateActivity(options: UpdateActivityOptions): Promise<void>;

  /**
   * End a Live Activity.
   *
   * @param options - Options for ending the activity
   * @returns Promise that resolves when activity is ended
   * @throws Error if activity not found or end fails
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.endActivity({
   *   activityId: 'abc123',
   *   data: { status: 'Delivered' },
   *   dismissalPolicy: 'after',
   *   dismissAfter: Date.now() + 3600000 // 1 hour from now
   * });
   * ```
   */
  endActivity(options: EndActivityOptions): Promise<void>;

  /**
   * Get all currently active Live Activities.
   *
   * @returns Promise that resolves with list of activities
   * @since 1.0.0
   * @example
   * ```typescript
   * const { activities } = await CapgoLiveActivities.getAllActivities();
   * activities.forEach(activity => {
   *   console.log(`Activity ${activity.activityId}: ${activity.state}`);
   * });
   * ```
   */
  getAllActivities(): Promise<GetAllActivitiesResult>;

  /**
   * Save an image to the shared App Group container for use in Live Activities.
   * Images must be saved to the shared container to be accessible from the widget extension.
   *
   * @param options - Options for saving the image
   * @returns Promise that resolves with the save result
   * @since 1.0.0
   * @example
   * ```typescript
   * const { success, imageName } = await CapgoLiveActivities.saveImage({
   *   imageData: 'base64EncodedImageData...',
   *   name: 'product-image',
   *   compressionQuality: 0.8
   * });
   * // Use in layout with: { type: 'image', source: 'saved', value: imageName }
   * ```
   */
  saveImage(options: SaveImageOptions): Promise<SaveImageResult>;

  /**
   * Remove a saved image from the shared container.
   *
   * @param options - Options for removing the image
   * @returns Promise that resolves with the removal result
   * @since 1.0.0
   * @example
   * ```typescript
   * const { success } = await CapgoLiveActivities.removeImage({ name: 'product-image' });
   * ```
   */
  removeImage(options: RemoveImageOptions): Promise<RemoveImageResult>;

  /**
   * List all saved images in the shared container.
   *
   * @returns Promise that resolves with list of image names
   * @since 1.0.0
   * @example
   * ```typescript
   * const { images } = await CapgoLiveActivities.listImages();
   * console.log('Saved images:', images);
   * ```
   */
  listImages(): Promise<ListImagesResult>;

  /**
   * Remove all saved images from the shared container.
   *
   * @returns Promise that resolves when cleanup is complete
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.cleanupImages();
   * ```
   */
  cleanupImages(): Promise<void>;

  /**
   * Get the native Capacitor plugin version.
   *
   * @returns Promise that resolves with the plugin version
   * @since 1.0.0
   * @example
   * ```typescript
   * const { version } = await CapgoLiveActivities.getPluginVersion();
   * console.log('Plugin version:', version);
   * ```
   */
  getPluginVersion(): Promise<{ version: string }>;

  // ============================================================================
  // TIMER SEQUENCE METHODS (for workout/sport timers)
  // Works on iOS (Live Activity + Dynamic Island) and Android (Foreground Notification)
  // ============================================================================

  /**
   * Start a timer sequence for workouts/sports.
   * On iOS: Shows in Live Activity and Dynamic Island
   * On Android: Shows as a foreground notification with timer
   *
   * @param options - Timer sequence configuration
   * @returns Promise that resolves with the sequence ID
   * @since 1.0.0
   * @example
   * ```typescript
   * const { sequenceId } = await CapgoLiveActivities.startTimerSequence({
   *   title: 'HIIT Workout',
   *   steps: [
   *     { duration: 30, title: 'Jumping Jacks', subtitle: 'Warm up', color: '#FF6B00', icon: 'figure.jumprope' },
   *     { duration: 10, title: 'Rest', color: '#00C853', icon: 'pause.circle' },
   *     { duration: 45, title: 'Burpees', subtitle: 'High intensity', color: '#FF0000', icon: 'flame.fill' },
   *     { duration: 15, title: 'Rest', color: '#00C853', icon: 'pause.circle' },
   *     { duration: 45, title: 'Mountain Climbers', color: '#FF0000', icon: 'figure.run' },
   *     { duration: 15, title: 'Rest', color: '#00C853', icon: 'pause.circle' },
   *   ],
   *   loop: true,
   *   loopCount: 3,
   *   soundEnabled: true,
   *   vibrateEnabled: true,
   *   countdownBeeps: true,
   *   tapUrl: 'myapp://workout/hiit'
   * });
   * ```
   */
  startTimerSequence(options: TimerSequenceOptions): Promise<TimerSequenceResult>;

  /**
   * Pause the timer sequence.
   *
   * @param options - Options containing the sequence ID
   * @returns Promise that resolves when paused
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.pauseTimerSequence({ sequenceId: 'abc123' });
   * ```
   */
  pauseTimerSequence(options: { sequenceId: string }): Promise<void>;

  /**
   * Resume a paused timer sequence.
   *
   * @param options - Options containing the sequence ID
   * @returns Promise that resolves when resumed
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.resumeTimerSequence({ sequenceId: 'abc123' });
   * ```
   */
  resumeTimerSequence(options: { sequenceId: string }): Promise<void>;

  /**
   * Stop and dismiss the timer sequence.
   *
   * @param options - Options containing the sequence ID
   * @returns Promise that resolves when stopped
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.stopTimerSequence({ sequenceId: 'abc123' });
   * ```
   */
  stopTimerSequence(options: { sequenceId: string }): Promise<void>;

  /**
   * Skip to the next step in the sequence.
   *
   * @param options - Options containing the sequence ID
   * @returns Promise that resolves when skipped
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.skipTimerStep({ sequenceId: 'abc123' });
   * ```
   */
  skipTimerStep(options: { sequenceId: string }): Promise<void>;

  /**
   * Go back to the previous step in the sequence.
   *
   * @param options - Options containing the sequence ID
   * @returns Promise that resolves when moved back
   * @since 1.0.0
   * @example
   * ```typescript
   * await CapgoLiveActivities.previousTimerStep({ sequenceId: 'abc123' });
   * ```
   */
  previousTimerStep(options: { sequenceId: string }): Promise<void>;

  /**
   * Get the current state of a timer sequence.
   *
   * @param options - Options containing the sequence ID
   * @returns Promise that resolves with the current state
   * @since 1.0.0
   * @example
   * ```typescript
   * const state = await CapgoLiveActivities.getTimerState({ sequenceId: 'abc123' });
   * console.log(`Step ${state.currentStepIndex + 1}/${state.totalSteps}: ${state.currentStep.title}`);
   * console.log(`Time remaining: ${state.remainingSeconds}s`);
   * ```
   */
  getTimerState(options: GetTimerStateOptions): Promise<TimerSequenceState>;

  /**
   * Add a listener for timer sequence events.
   * Events include: stepChange, complete, tick, paused, resumed, stopped, loopComplete
   *
   * @param eventName - The event name to listen for
   * @param callback - Callback function that receives the event
   * @returns Promise that resolves with a handle to remove the listener
   * @since 1.0.0
   * @example
   * ```typescript
   * const handle = await CapgoLiveActivities.addListener('timerSequenceEvent', (event) => {
   *   if (event.type === 'stepChange') {
   *     console.log(`Now: ${event.state.currentStep.title}`);
   *   } else if (event.type === 'complete') {
   *     console.log('Workout complete!');
   *   } else if (event.type === 'tick') {
   *     console.log(`${event.state.remainingSeconds}s remaining`);
   *   }
   * });
   *
   * // Later, to remove the listener:
   * handle.remove();
   * ```
   */
  addListener(
    eventName: 'timerSequenceEvent',
    callback: TimerSequenceCallback,
  ): Promise<{ remove: () => Promise<void> }>;
}
