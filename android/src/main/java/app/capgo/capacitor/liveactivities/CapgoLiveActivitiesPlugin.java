package app.capgo.capacitor.liveactivities;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.service.notification.StatusBarNotification;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Android implementation for Live Activities plugin.
 * A Live Activity started with an {@code android} layout is an ongoing notification, which
 * Android can promote to a Live Update from Android 16 QPR1 (a status bar chip, the top of the
 * lock screen).
 * Timer sequences work on Android using foreground notifications.
 */
@CapacitorPlugin(
    name = "CapgoLiveActivities",
    permissions = { @Permission(strings = { Manifest.permission.POST_NOTIFICATIONS }, alias = CapgoLiveActivitiesPlugin.NOTIFICATIONS) }
)
public class CapgoLiveActivitiesPlugin extends Plugin {

    static final String NOTIFICATIONS = "notifications";

    private static final String CHANNEL_ID = "timer_sequence_channel";
    private static final int NOTIFICATION_ID = 1001;

    // Live Activities as notifications
    private static final String ACTIVITY_CHANNEL_ID = "live_activities_channel";
    private static final String ACTIVITY_PREFS = "CapgoLiveActivities";
    private static final String ACTIVITY_KEY_PREFIX = "activity:";
    private static final String NEXT_NOTIFICATION_ID_KEY = "nextNotificationId";
    // timer sequences use 1001
    private static final int FIRST_ACTIVITY_NOTIFICATION_ID = 2000;
    // Notification.EXTRA_REQUEST_PROMOTED_ONGOING: public from API 36.1 (Android 16 QPR1), where
    // apps can request promotion; ignored before
    private static final String EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing";
    // Notification.EXTRA_CHRONOMETER_COUNT_DOWN (API 24)
    private static final String EXTRA_CHRONOMETER_COUNT_DOWN = "android.chronometerCountDown";
    // A notification just posted may not be listed as shown yet: not taken for dismissed before
    private static final long JUST_POSTED_MS = 5000;
    private final String pluginVersion = "1.3.3";

    private final Map<String, TimerSequenceInfo> timerSequences = new HashMap<>();
    private final Handler handler = new Handler(Looper.getMainLooper());

    private static class TimerSequenceInfo {

        JSONObject options;
        JSONArray steps;
        int currentStepIndex;
        int remainingSeconds;
        int totalRemainingSeconds;
        int elapsedSeconds;
        boolean isRunning;
        boolean isPaused;
        boolean isComplete;
        int currentLoop;
        int totalLoops;
        Runnable timerRunnable;
        long startTime;
    }

    @Override
    public void load() {
        super.load();
        createNotificationChannel();
        createActivityChannel();
    }

    private void createActivityChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Default importance (a Live Update needs more than "min"), but silent: an activity
            // changes often and never rings.
            NotificationChannel channel = new NotificationChannel(
                ACTIVITY_CHANNEL_ID,
                "Live Activities",
                NotificationManager.IMPORTANCE_DEFAULT
            );
            channel.setDescription("Ongoing activities, such as a timer or a delivery");
            channel.setSound(null, null);
            channel.enableVibration(false);
            channel.setShowBadge(false);

            NotificationManager notificationManager = getContext().getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Timer Notifications", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Workout timer notifications");
            channel.setShowBadge(true);
            channel.enableVibration(true);

            NotificationManager notificationManager = getContext().getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }

    @PluginMethod
    public void areActivitiesSupported(PluginCall call) {
        JSObject ret = new JSObject();
        boolean enabled = NotificationManagerCompat.from(getContext()).areNotificationsEnabled();
        // Not granted yet (Android 13+): startActivity asks for it
        boolean canAsk =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && getPermissionState(NOTIFICATIONS) != PermissionState.DENIED;

        ret.put("supported", enabled || canAsk);
        if (!enabled && !canAsk) {
            ret.put("reason", "Notifications are turned off for this app");
        }

        if (Build.VERSION.SDK_INT >= 36) {
            NotificationManager notificationManager = getContext().getSystemService(NotificationManager.class);
            ret.put("canPostPromoted", notificationManager != null && notificationManager.canPostPromotedNotifications());
        }

        call.resolve(ret);
    }

    @PluginMethod
    public void startActivity(PluginCall call) {
        if (call.getObject("android") == null) {
            call.reject("On Android, a Live Activity needs an `android` layout (an ongoing notification)");
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && getPermissionState(NOTIFICATIONS) != PermissionState.GRANTED) {
            requestPermissionForAlias(NOTIFICATIONS, call, "activityNotificationsPermissionCallback");
            return;
        }

        startActivityImpl(call);
    }

    @PermissionCallback
    private void activityNotificationsPermissionCallback(PluginCall call) {
        if (getPermissionState(NOTIFICATIONS) != PermissionState.GRANTED) {
            call.reject("Notification permission was not granted");
            return;
        }

        startActivityImpl(call);
    }

    private void startActivityImpl(PluginCall call) {
        try {
            String activityId = UUID.randomUUID().toString();
            JSONObject activity = new JSONObject();

            activity.put("notificationId", nextActivityNotificationId());
            activity.put("startDate", System.currentTimeMillis());
            activity.put("android", call.getObject("android"));
            activity.put("data", objectOrEmpty(call.getObject("data")));

            JSObject behavior = call.getObject("behavior");
            if (behavior != null && behavior.has("widgetUrl")) {
                activity.put("widgetUrl", behavior.getString("widgetUrl"));
            }

            Boolean promotable = postActivity(activity, null);
            saveActivity(activityId, activity);

            JSObject ret = new JSObject();
            ret.put("activityId", activityId);
            ret.put("promotable", promotable);
            call.resolve(ret);
        } catch (JSONException e) {
            call.reject("Invalid activity options: " + e.getMessage());
        }
    }

    @PluginMethod
    public void updateActivity(PluginCall call) {
        String activityId = call.getString("activityId");
        JSONObject activity = activityId == null ? null : loadActivity(activityId);

        if (activity == null) {
            call.reject("Activity not found");
            return;
        }

        try {
            // As on iOS, the data replaces the previous data
            activity.put("data", objectOrEmpty(call.getObject("data")));
            postActivity(activity, null);
            saveActivity(activityId, activity);
            call.resolve();
        } catch (JSONException e) {
            call.reject("Invalid activity data: " + e.getMessage());
        }
    }

    @PluginMethod
    public void endActivity(PluginCall call) {
        String activityId = call.getString("activityId");
        JSONObject activity = activityId == null ? null : loadActivity(activityId);

        if (activity == null) {
            call.reject("Activity not found");
            return;
        }

        try {
            JSObject data = call.getObject("data");
            if (data != null) {
                activity.put("data", data);
            }

            long dismissAfter = call.getLong("dismissAfter", 0L);
            long remaining = dismissAfter - System.currentTimeMillis();

            if ("after".equals(call.getString("dismissalPolicy")) && remaining > 0) {
                // the final state stays, no longer ongoing, until dismissAfter
                postActivity(activity, remaining);
            } else {
                NotificationManagerCompat.from(getContext()).cancel(activity.getInt("notificationId"));
            }

            removeActivity(activityId);
            call.resolve();
        } catch (JSONException e) {
            call.reject("Invalid activity data: " + e.getMessage());
        }
    }

    @PluginMethod
    public void getAllActivities(PluginCall call) {
        // While the app's notifications (or the activities' channel) are blocked, none is shown:
        // that says nothing of whether the user dismissed one
        Set<Integer> shown = activityNotificationsBlocked() ? null : shownNotificationIds();
        JSArray activities = new JSArray();
        Map<String, ?> stored = activityPrefs().getAll();

        for (Map.Entry<String, ?> entry : stored.entrySet()) {
            if (!entry.getKey().startsWith(ACTIVITY_KEY_PREFIX)) {
                continue;
            }

            String activityId = entry.getKey().substring(ACTIVITY_KEY_PREFIX.length());

            try {
                JSONObject activity = new JSONObject(String.valueOf(entry.getValue()));
                // Not shown: the user dismissed it (Android 14+ lets them)
                boolean justPosted = System.currentTimeMillis() - activity.optLong("postedAt", 0) < JUST_POSTED_MS;
                boolean active = shown == null || justPosted || shown.contains(activity.getInt("notificationId"));

                JSObject info = new JSObject();
                info.put("activityId", activityId);
                info.put("state", active ? "active" : "dismissed");
                info.put("startDate", activity.optLong("startDate", 0));
                info.put("data", JSObject.fromJSONObject(activity.optJSONObject("data")));
                activities.put(info);

                if (!active) {
                    removeActivity(activityId);
                }
            } catch (JSONException e) {
                removeActivity(activityId);
            }
        }

        JSObject ret = new JSObject();
        ret.put("activities", activities);
        call.resolve(ret);
    }

    @PluginMethod
    public void saveImage(PluginCall call) {
        call.reject("Live Activities are only available on iOS");
    }

    @PluginMethod
    public void removeImage(PluginCall call) {
        call.reject("Live Activities are only available on iOS");
    }

    @PluginMethod
    public void listImages(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("images", new JSArray());
        call.resolve(ret);
    }

    @PluginMethod
    public void cleanupImages(PluginCall call) {
        call.resolve();
    }

    @PluginMethod
    public void getPluginVersion(final PluginCall call) {
        try {
            final JSObject ret = new JSObject();
            ret.put("version", this.pluginVersion);
            call.resolve(ret);
        } catch (final Exception e) {
            call.reject("Could not get plugin version", e);
        }
    }

    // ============================================================================
    // Timer Sequence Methods - Work on Android via notifications
    // ============================================================================

    @PluginMethod
    public void startTimerSequence(PluginCall call) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (getPermissionState(NOTIFICATIONS) != PermissionState.GRANTED) {
                requestPermissionForAlias(NOTIFICATIONS, call, "postNotificationsPermissionCallback");
                return;
            }
        }
        startTimerSequenceImpl(call);
    }

    @PermissionCallback
    private void postNotificationsPermissionCallback(PluginCall call) {
        startTimerSequenceImpl(call);
    }

    private void startTimerSequenceImpl(PluginCall call) {
        try {
            JSONArray steps = call.getArray("steps");
            if (steps == null || steps.length() == 0) {
                call.reject("steps array is required and cannot be empty");
                return;
            }

            String sequenceId = UUID.randomUUID().toString();
            String title = call.getString("title", "Timer");
            boolean loop = call.getBoolean("loop", false);
            int loopCount = call.getInt("loopCount", 0);
            boolean soundEnabled = call.getBoolean("soundEnabled", true);
            boolean vibrateEnabled = call.getBoolean("vibrateEnabled", true);
            boolean countdownBeeps = call.getBoolean("countdownBeeps", true);
            String tapUrl = call.getString("tapUrl");

            // Calculate total duration
            int totalDuration = 0;
            for (int i = 0; i < steps.length(); i++) {
                JSONObject step = steps.getJSONObject(i);
                totalDuration += step.optInt("duration", 0);
            }

            JSONObject firstStep = steps.getJSONObject(0);
            int firstDuration = firstStep.optInt("duration", 0);

            TimerSequenceInfo info = new TimerSequenceInfo();
            info.options = new JSONObject();
            info.options.put("title", title);
            info.options.put("loop", loop);
            info.options.put("loopCount", loopCount);
            info.options.put("soundEnabled", soundEnabled);
            info.options.put("vibrateEnabled", vibrateEnabled);
            info.options.put("countdownBeeps", countdownBeeps);
            info.options.put("tapUrl", tapUrl);

            info.steps = steps;
            info.currentStepIndex = 0;
            info.remainingSeconds = firstDuration;
            info.totalRemainingSeconds = totalDuration;
            info.elapsedSeconds = 0;
            info.isRunning = true;
            info.isPaused = false;
            info.isComplete = false;
            info.currentLoop = 1;
            info.totalLoops = loopCount;
            info.startTime = System.currentTimeMillis();

            timerSequences.put(sequenceId, info);

            // Show initial notification
            updateNotification(sequenceId);

            // Start the timer
            startTimer(sequenceId);

            // Emit initial step change event
            emitTimerEvent(sequenceId, "stepChange");

            JSObject ret = new JSObject();
            ret.put("sequenceId", sequenceId);
            call.resolve(ret);
        } catch (JSONException e) {
            call.reject("Error parsing timer options: " + e.getMessage());
        }
    }

    private void startTimer(final String sequenceId) {
        final TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) return;

        info.timerRunnable = new Runnable() {
            @Override
            public void run() {
                tickTimer(sequenceId);
                TimerSequenceInfo currentInfo = timerSequences.get(sequenceId);
                if (currentInfo != null && currentInfo.isRunning && !currentInfo.isComplete) {
                    handler.postDelayed(this, 1000);
                }
            }
        };

        handler.postDelayed(info.timerRunnable, 1000);
    }

    private void tickTimer(String sequenceId) {
        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null || !info.isRunning || info.isPaused || info.isComplete) return;

        info.remainingSeconds--;
        info.totalRemainingSeconds--;
        info.elapsedSeconds++;

        // Countdown beeps in last 3 seconds
        boolean countdownBeeps = info.options.optBoolean("countdownBeeps", true);
        if (countdownBeeps && info.remainingSeconds <= 3 && info.remainingSeconds > 0) {
            playBeep();
        }

        // Update notification
        updateNotification(sequenceId);

        // Emit tick event
        emitTimerEvent(sequenceId, "tick");

        // Check if current step is complete
        if (info.remainingSeconds <= 0) {
            advanceToNextStep(sequenceId);
        }
    }

    private void advanceToNextStep(String sequenceId) {
        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) return;

        boolean soundEnabled = info.options.optBoolean("soundEnabled", true);
        boolean vibrateEnabled = info.options.optBoolean("vibrateEnabled", true);

        try {
            if (info.currentStepIndex < info.steps.length() - 1) {
                // Move to next step
                info.currentStepIndex++;
                JSONObject nextStep = info.steps.getJSONObject(info.currentStepIndex);
                info.remainingSeconds = nextStep.optInt("duration", 0);

                if (soundEnabled) playStepChangeSound();
                if (vibrateEnabled) vibrate();

                updateNotification(sequenceId);
                emitTimerEvent(sequenceId, "stepChange");
            } else {
                // End of sequence
                boolean loop = info.options.optBoolean("loop", false);
                int loopCount = info.options.optInt("loopCount", 0);

                if (loop && (loopCount == 0 || info.currentLoop < loopCount)) {
                    // Loop back
                    info.currentLoop++;
                    info.currentStepIndex = 0;
                    JSONObject firstStep = info.steps.getJSONObject(0);
                    info.remainingSeconds = firstStep.optInt("duration", 0);

                    // Recalculate total remaining
                    int totalDuration = 0;
                    for (int i = 0; i < info.steps.length(); i++) {
                        JSONObject step = info.steps.getJSONObject(i);
                        totalDuration += step.optInt("duration", 0);
                    }
                    info.totalRemainingSeconds = totalDuration;

                    if (soundEnabled) playStepChangeSound();
                    if (vibrateEnabled) vibrate();

                    updateNotification(sequenceId);
                    emitTimerEvent(sequenceId, "loopComplete");
                    emitTimerEvent(sequenceId, "stepChange");
                } else {
                    // Complete
                    info.isComplete = true;
                    info.isRunning = false;

                    if (soundEnabled) playCompleteSound();
                    if (vibrateEnabled) vibrateComplete();

                    showCompleteNotification(sequenceId);
                    emitTimerEvent(sequenceId, "complete");
                }
            }
        } catch (JSONException e) {
            // Handle error
        }
    }

    @PluginMethod
    public void pauseTimerSequence(PluginCall call) {
        String sequenceId = call.getString("sequenceId");
        if (sequenceId == null) {
            call.reject("sequenceId is required");
            return;
        }

        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) {
            call.reject("Timer sequence not found");
            return;
        }

        info.isPaused = true;
        updateNotification(sequenceId);
        emitTimerEvent(sequenceId, "paused");
        call.resolve();
    }

    @PluginMethod
    public void resumeTimerSequence(PluginCall call) {
        String sequenceId = call.getString("sequenceId");
        if (sequenceId == null) {
            call.reject("sequenceId is required");
            return;
        }

        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) {
            call.reject("Timer sequence not found");
            return;
        }

        info.isPaused = false;
        updateNotification(sequenceId);
        emitTimerEvent(sequenceId, "resumed");
        call.resolve();
    }

    @PluginMethod
    public void stopTimerSequence(PluginCall call) {
        String sequenceId = call.getString("sequenceId");
        if (sequenceId == null) {
            call.reject("sequenceId is required");
            return;
        }

        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) {
            call.reject("Timer sequence not found");
            return;
        }

        info.isRunning = false;
        if (info.timerRunnable != null) {
            handler.removeCallbacks(info.timerRunnable);
        }

        cancelNotification();
        emitTimerEvent(sequenceId, "stopped");
        timerSequences.remove(sequenceId);
        call.resolve();
    }

    @PluginMethod
    public void skipTimerStep(PluginCall call) {
        String sequenceId = call.getString("sequenceId");
        if (sequenceId == null) {
            call.reject("sequenceId is required");
            return;
        }

        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) {
            call.reject("Timer sequence not found");
            return;
        }

        try {
            if (info.currentStepIndex < info.steps.length() - 1) {
                info.totalRemainingSeconds -= info.remainingSeconds;
                info.elapsedSeconds += info.remainingSeconds;
                info.currentStepIndex++;
                JSONObject nextStep = info.steps.getJSONObject(info.currentStepIndex);
                info.remainingSeconds = nextStep.optInt("duration", 0);

                updateNotification(sequenceId);
                emitTimerEvent(sequenceId, "stepChange");
            }
        } catch (JSONException e) {
            // Handle error
        }

        call.resolve();
    }

    @PluginMethod
    public void previousTimerStep(PluginCall call) {
        String sequenceId = call.getString("sequenceId");
        if (sequenceId == null) {
            call.reject("sequenceId is required");
            return;
        }

        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) {
            call.reject("Timer sequence not found");
            return;
        }

        try {
            if (info.currentStepIndex > 0) {
                JSONObject currentStep = info.steps.getJSONObject(info.currentStepIndex);
                int currentDuration = currentStep.optInt("duration", 0);
                info.totalRemainingSeconds += currentDuration - info.remainingSeconds;
                info.elapsedSeconds -= currentDuration - info.remainingSeconds;

                info.currentStepIndex--;
                JSONObject prevStep = info.steps.getJSONObject(info.currentStepIndex);
                int prevDuration = prevStep.optInt("duration", 0);
                info.remainingSeconds = prevDuration;
                info.totalRemainingSeconds += prevDuration;
                info.elapsedSeconds -= prevDuration;

                updateNotification(sequenceId);
                emitTimerEvent(sequenceId, "stepChange");
            }
        } catch (JSONException e) {
            // Handle error
        }

        call.resolve();
    }

    @PluginMethod
    public void getTimerState(PluginCall call) {
        String sequenceId = call.getString("sequenceId");
        if (sequenceId == null) {
            call.reject("sequenceId is required");
            return;
        }

        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) {
            call.reject("Timer sequence not found");
            return;
        }

        call.resolve(buildStateObject(sequenceId, info));
    }

    private JSObject buildStateObject(String sequenceId, TimerSequenceInfo info) {
        JSObject state = new JSObject();
        try {
            JSONObject currentStep = info.steps.getJSONObject(info.currentStepIndex);

            state.put("sequenceId", sequenceId);
            state.put("isRunning", info.isRunning);
            state.put("isPaused", info.isPaused);
            state.put("isComplete", info.isComplete);
            state.put("currentStepIndex", info.currentStepIndex);
            state.put("totalSteps", info.steps.length());
            state.put("currentStep", JSObject.fromJSONObject(currentStep));
            state.put("remainingSeconds", info.remainingSeconds);
            state.put("totalRemainingSeconds", info.totalRemainingSeconds);
            state.put("elapsedSeconds", info.elapsedSeconds);
            state.put("currentLoop", info.currentLoop);
            state.put("totalLoops", info.totalLoops);
        } catch (JSONException e) {
            // Handle error
        }
        return state;
    }

    private void emitTimerEvent(String sequenceId, String type) {
        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) return;

        JSObject event = new JSObject();
        event.put("type", type);
        event.put("sequenceId", sequenceId);
        event.put("state", buildStateObject(sequenceId, info));

        notifyListeners("timerSequenceEvent", event);
    }

    // ============================================================================
    // Notification Methods
    // ============================================================================

    private void updateNotification(String sequenceId) {
        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) return;

        try {
            JSONObject currentStep = info.steps.getJSONObject(info.currentStepIndex);
            String stepTitle = currentStep.optString("title", "Timer");
            String stepSubtitle = currentStep.optString("subtitle", "");
            String stepColor = currentStep.optString("color", "#007AFF");

            String title = info.options.optString("title", "Timer");
            String contentText = String.format("%s - %s", stepTitle, formatTime(info.remainingSeconds));
            if (!stepSubtitle.isEmpty()) {
                contentText = String.format("%s (%s) - %s", stepTitle, stepSubtitle, formatTime(info.remainingSeconds));
            }

            String progressText = String.format("Step %d/%d", info.currentStepIndex + 1, info.steps.length());
            if (info.isPaused) {
                progressText += " (Paused)";
            }

            NotificationCompat.Builder builder = new NotificationCompat.Builder(getContext(), CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title + " - " + progressText)
                .setContentText(contentText)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

            // Add tap action
            String tapUrl = info.options.optString("tapUrl", null);
            if (tapUrl != null && !tapUrl.isEmpty()) {
                Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(tapUrl));
                PendingIntent pendingIntent = PendingIntent.getActivity(
                    getContext(),
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
                builder.setContentIntent(pendingIntent);
            }

            // Add progress bar
            int totalStepDuration = currentStep.optInt("duration", 0);
            int progress = totalStepDuration > 0 ? ((totalStepDuration - info.remainingSeconds) * 100) / totalStepDuration : 0;
            builder.setProgress(100, progress, false);

            showNotification(builder.build());
        } catch (JSONException e) {
            // Handle error
        }
    }

    private void showCompleteNotification(String sequenceId) {
        TimerSequenceInfo info = timerSequences.get(sequenceId);
        if (info == null) return;

        String title = info.options.optString("title", "Timer");

        NotificationCompat.Builder builder = new NotificationCompat.Builder(getContext(), CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title + " Complete!")
            .setContentText("Great job! Your workout is finished.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM);

        showNotification(builder.build());
    }

    private void showNotification(Notification notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (
                ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return;
            }
        }

        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(getContext());
        notificationManager.notify(NOTIFICATION_ID, notification);
    }

    private void cancelNotification() {
        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(getContext());
        notificationManager.cancel(NOTIFICATION_ID);
    }

    private String formatTime(int seconds) {
        int mins = seconds / 60;
        int secs = seconds % 60;
        return String.format("%d:%02d", mins, secs);
    }

    // ============================================================================
    // Live Activities as notifications
    // ============================================================================

    /**
     * Shows (or updates) an activity's notification. With {@code timeoutMs}, the activity has
     * ended: its final state shows, no longer ongoing, for that long.
     *
     * @return whether Android 16+ considers it promotable to a Live Update (null before 16)
     */
    private Boolean postActivity(JSONObject activity, Long timeoutMs) throws JSONException {
        JSONObject android = activity.getJSONObject("android");
        Map<String, Object> data = toMap(activity.optJSONObject("data"));
        boolean ended = timeoutMs != null;

        NotificationCompat.Builder builder = new NotificationCompat.Builder(getContext(), ACTIVITY_CHANNEL_ID)
            .setSmallIcon(smallIcon(android.optString("smallIcon", null)))
            .setContentTitle(ActivityTemplates.fill(android.optString("title", ""), data))
            .setOngoing(!ended)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            // as on iOS, an activity shows in full on the lock screen, unless the app says otherwise
            .setVisibility(
                "private".equals(android.optString("visibility"))
                    ? NotificationCompat.VISIBILITY_PRIVATE
                    : NotificationCompat.VISIBILITY_PUBLIC
            )
            .setContentIntent(activityTapIntent(activity));

        String text = ActivityTemplates.fill(android.optString("text", ""), data);
        if (!text.isEmpty()) {
            builder.setContentText(text);
        }

        Bundle extras = new Bundle();
        JSONObject timer = android.optJSONObject("timer");
        long timerDate = timer == null || ended ? 0 : ActivityTemplates.timestamp(timer.opt("targetDate"), data);

        if (timerDate > 0) {
            // Android's own chronometer: it counts by itself, up from a past date (or down to a
            // future one), with no update every second
            builder.setWhen(timerDate).setShowWhen(true).setUsesChronometer(true);
            if (timer.optBoolean("countDown", false)) {
                extras.putBoolean(EXTRA_CHRONOMETER_COUNT_DOWN, true);
            }
        } else {
            builder.setShowWhen(false);
        }

        if (ended) {
            builder.setTimeoutAfter(timeoutMs).setAutoCancel(true);
        } else {
            extras.putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true);
        }
        builder.addExtras(extras);

        Notification notification = builder.build();
        Boolean promotable = null;

        if (Build.VERSION.SDK_INT >= 36) {
            String chipText = ActivityTemplates.fill(android.optString("chipText", ""), data);
            if (!chipText.isEmpty() && !ended) {
                notification = Notification.Builder.recoverBuilder(getContext(), notification).setShortCriticalText(chipText).build();
            }
            promotable = !ended && notification.hasPromotableCharacteristics();
        }

        int notificationId = activity.getInt("notificationId");
        activity.put("postedAt", System.currentTimeMillis());
        showActivityNotification(notificationId, notification);

        // setTimeoutAfter only exists from Android 8: before, cancel it here (while the app runs)
        if (ended && Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            handler.postDelayed(() -> NotificationManagerCompat.from(getContext()).cancel(notificationId), timeoutMs);
        }

        return promotable;
    }

    private void showActivityNotification(int notificationId, Notification notification) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return;
        }

        NotificationManagerCompat.from(getContext()).notify(notificationId, notification);
    }

    // A drawable or mipmap of the app, by name; the app's icon without one
    private int smallIcon(String name) {
        Context context = getContext();

        if (name != null && !name.isEmpty()) {
            String resourceName = name.contains("/") ? name.substring(name.indexOf('/') + 1) : name;

            for (String type : new String[] { "drawable", "mipmap" }) {
                int id = context.getResources().getIdentifier(resourceName, type, context.getPackageName());
                if (id != 0) {
                    return id;
                }
            }
        }

        return context.getApplicationInfo().icon;
    }

    // Opens behavior.widgetUrl in the app, as on iOS; or just the app
    private PendingIntent activityTapIntent(JSONObject activity) throws JSONException {
        Context context = getContext();
        String widgetUrl = activity.optString("widgetUrl", "");
        Intent intent;

        if (!widgetUrl.isEmpty()) {
            intent = new Intent(Intent.ACTION_VIEW, Uri.parse(widgetUrl)).setPackage(context.getPackageName());
        } else {
            intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (intent == null) {
                return null;
            }
        }

        return PendingIntent.getActivity(
            context,
            activity.getInt("notificationId"),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }

    private boolean activityNotificationsBlocked() {
        NotificationManagerCompat notifications = NotificationManagerCompat.from(getContext());
        if (!notifications.areNotificationsEnabled()) {
            return true;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = getContext()
                .getSystemService(NotificationManager.class)
                .getNotificationChannel(ACTIVITY_CHANNEL_ID);
            return channel != null && channel.getImportance() == NotificationManager.IMPORTANCE_NONE;
        }

        return false;
    }

    // The ids of the app's notifications on screen now; null where Android cannot tell
    private Set<Integer> shownNotificationIds() {
        NotificationManager notificationManager = getContext().getSystemService(NotificationManager.class);
        if (notificationManager == null) {
            return null;
        }

        Set<Integer> ids = new HashSet<>();
        for (StatusBarNotification notification : notificationManager.getActiveNotifications()) {
            ids.add(notification.getId());
        }
        return ids;
    }

    // Activities are kept across app restarts: their notifications outlive the app's process
    private SharedPreferences activityPrefs() {
        return getContext().getSharedPreferences(ACTIVITY_PREFS, Context.MODE_PRIVATE);
    }

    private JSONObject loadActivity(String activityId) {
        String json = activityPrefs().getString(ACTIVITY_KEY_PREFIX + activityId, null);
        if (json == null) {
            return null;
        }

        try {
            return new JSONObject(json);
        } catch (JSONException e) {
            return null;
        }
    }

    private void saveActivity(String activityId, JSONObject activity) {
        activityPrefs().edit().putString(ACTIVITY_KEY_PREFIX + activityId, activity.toString()).apply();
    }

    private void removeActivity(String activityId) {
        activityPrefs().edit().remove(ACTIVITY_KEY_PREFIX + activityId).apply();
    }

    private synchronized int nextActivityNotificationId() {
        SharedPreferences prefs = activityPrefs();
        int id = prefs.getInt(NEXT_NOTIFICATION_ID_KEY, FIRST_ACTIVITY_NOTIFICATION_ID);
        prefs.edit().putInt(NEXT_NOTIFICATION_ID_KEY, id + 1).apply();
        return id;
    }

    private static JSONObject objectOrEmpty(JSONObject object) {
        return object == null ? new JSONObject() : object;
    }

    private static Map<String, Object> toMap(JSONObject object) {
        Map<String, Object> map = new HashMap<>();
        if (object == null) {
            return map;
        }

        Iterator<String> keys = object.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = object.opt(key);
            map.put(key, value == JSONObject.NULL ? null : value);
        }
        return map;
    }

    // ============================================================================
    // Sound and Vibration
    // ============================================================================

    private void playBeep() {
        try {
            Uri notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
            android.media.Ringtone r = RingtoneManager.getRingtone(getContext(), notification);
            r.play();
        } catch (Exception e) {
            // Ignore
        }
    }

    private void playStepChangeSound() {
        playBeep();
    }

    private void playCompleteSound() {
        try {
            Uri notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
            android.media.Ringtone r = RingtoneManager.getRingtone(getContext(), notification);
            r.play();
        } catch (Exception e) {
            // Ignore
        }
    }

    private void vibrate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                VibratorManager vibratorManager = (VibratorManager) getContext().getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
                Vibrator vibrator = vibratorManager.getDefaultVibrator();
                vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                Vibrator vibrator = (Vibrator) getContext().getSystemService(Context.VIBRATOR_SERVICE);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE));
                } else {
                    vibrator.vibrate(200);
                }
            }
        } catch (Exception e) {
            // Ignore
        }
    }

    private void vibrateComplete() {
        try {
            long[] pattern = { 0, 300, 100, 300, 100, 300 };
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                VibratorManager vibratorManager = (VibratorManager) getContext().getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
                Vibrator vibrator = vibratorManager.getDefaultVibrator();
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1));
            } else {
                Vibrator vibrator = (Vibrator) getContext().getSystemService(Context.VIBRATOR_SERVICE);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1));
                } else {
                    vibrator.vibrate(pattern, -1);
                }
            }
        } catch (Exception e) {
            // Ignore
        }
    }
}
