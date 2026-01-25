package app.capgo.capacitor.liveactivities;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Android stub for Live Activities plugin.
 * Live Activities are an iOS-only feature, so this plugin provides
 * graceful fallbacks on Android.
 */
@CapacitorPlugin(name = "CapgoLiveActivities")
public class CapgoLiveActivitiesPlugin extends Plugin {

    private final String pluginVersion = "1.0.0";

    @PluginMethod
    public void areActivitiesSupported(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("supported", false);
        ret.put("reason", "Live Activities are only available on iOS");
        call.resolve(ret);
    }

    @PluginMethod
    public void startActivity(PluginCall call) {
        call.reject("Live Activities are only available on iOS");
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
}
