package app.capgo.capacitor.liveactivities;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Fills an Android activity's text from its data, as the iOS layout renderer does: a
 * {@code {{key}}} placeholder takes the value of {@code key} in the activity's data.
 */
final class ActivityTemplates {

    // The iOS renderer's pattern (CapgoLayoutRenderer.interpolate): any key up to the closing braces, trimmed
    private static final Pattern PLACEHOLDER = Pattern.compile("\\{\\{([^}]+)\\}\\}");

    private ActivityTemplates() {}

    /** The template with each {@code {{key}}} replaced by its value; a missing key is left empty. */
    static String fill(String template, Map<String, ?> data) {
        if (template == null) {
            return "";
        }

        Matcher matcher = PLACEHOLDER.matcher(template);
        StringBuilder result = new StringBuilder();

        while (matcher.find()) {
            Object value = data == null ? null : data.get(matcher.group(1).trim());
            matcher.appendReplacement(result, Matcher.quoteReplacement(format(value)));
        }
        matcher.appendTail(result);

        return result.toString();
    }

    /**
     * A timer's date, in milliseconds since the epoch: a number, or the key of a number in the
     * data (as the iOS {@code timer} element's {@code targetDate}). 0 when there is none.
     */
    static long timestamp(Object target, Map<String, ?> data) {
        Object value = target instanceof String && data != null ? data.get(target) : target;

        if (value instanceof Number) {
            return ((Number) value).longValue();
        }

        if (value instanceof String) {
            try {
                return (long) Double.parseDouble((String) value);
            } catch (NumberFormatException e) {
                return 0;
            }
        }

        return 0;
    }

    // 12, not 12.0: data crosses the bridge as JSON, where every number may be a double
    private static String format(Object value) {
        // (the plugin maps JSON's null to null before it gets here)
        if (value == null) {
            return "";
        }

        if (value instanceof Double || value instanceof Float) {
            double number = ((Number) value).doubleValue();

            // within a long's range: past it, (long) would saturate
            if (number == Math.rint(number) && Math.abs(number) < 1e18) {
                return String.valueOf((long) number);
            }
        }

        return String.valueOf(value);
    }
}
