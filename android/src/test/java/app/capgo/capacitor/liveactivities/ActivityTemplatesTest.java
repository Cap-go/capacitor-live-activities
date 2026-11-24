package app.capgo.capacitor.liveactivities;

import static org.junit.Assert.assertEquals;

import java.util.HashMap;
import java.util.Map;
import org.junit.Test;

public class ActivityTemplatesTest {

    private static Map<String, Object> data() {
        Map<String, Object> data = new HashMap<>();
        data.put("orderNumber", "12345");
        data.put("eta", 10.0);
        data.put("progress", 0.6);
        data.put("since", 1700000000000.0);
        data.put("missingValue", null);
        return data;
    }

    @Test
    public void fillsPlaceholdersFromData() {
        assertEquals("Order #12345", ActivityTemplates.fill("Order #{{orderNumber}}", data()));
        assertEquals("ETA 10 min", ActivityTemplates.fill("ETA {{ eta }} min", data()));
        assertEquals("0.6", ActivityTemplates.fill("{{progress}}", data()));
    }

    @Test
    public void leavesMissingValuesEmpty() {
        assertEquals("[]", ActivityTemplates.fill("[{{nope}}]", data()));
        assertEquals("[]", ActivityTemplates.fill("[{{missingValue}}]", data()));
        assertEquals("", ActivityTemplates.fill(null, data()));
    }

    @Test
    public void keepsDollarSignsAndBackslashes() {
        Map<String, Object> data = new HashMap<>();
        data.put("price", "$5 \\ off");
        assertEquals("$5 \\ off", ActivityTemplates.fill("{{price}}", data));
    }

    @Test
    public void readsTimerDatesFromDataOrLiterals() {
        assertEquals(1700000000000L, ActivityTemplates.timestamp("since", data()));
        assertEquals(42L, ActivityTemplates.timestamp(42, data()));
        assertEquals(0L, ActivityTemplates.timestamp("nope", data()));
        assertEquals(0L, ActivityTemplates.timestamp(null, data()));
    }
}
