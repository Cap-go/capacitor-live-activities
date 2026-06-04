package app.capgo.capacitor.liveactivities;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Android implementation for Live Activities plugin.
 * Live Activities are an iOS-only feature, but timer sequences work on Android
 * using foreground notifications.
 */
@CapacitorPlugin(name = "CapgoLiveActivities")
public class CapgoLiveActivitiesPlugin extends Plugin {

    private static final String CHANNEL_ID = "timer_sequence_channel";
    private static final int NOTIFICATION_ID = 1001;
    private final String pluginVersion = "1.1.0";

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
        ret.put("supported", false);
        ret.put("reason", "Live Activities are only available on iOS. Timer sequences work on Android via notifications.");
        call.resolve(ret);
    }

    @PluginMethod
    public void startActivity(PluginCall call) {
        call.reject("Live Activities are only available on iOS. Use startTimerSequence for workout timers on Android.");
    }

    @PluginMethod
    public void updateActivity(PluginCall call) {
        call.reject("Live Activities are only available on iOS");
    }

    @PluginMethod
    public void endActivity(PluginCall call) {
        call.reject("Live Activities are only available on iOS");
    }

    @PluginMethod
    public void getAllActivities(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("activities", new JSArray());
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
