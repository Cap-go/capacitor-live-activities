/** Activity states the demo can select for Update and End. */
export const SELECTABLE_ACTIVITY_STATES = new Set(['active', 'stale']);

/** Return activities in a state the demo can update or end. */
export function filterSelectableActivities(activities) {
  return activities?.filter((item) => SELECTABLE_ACTIVITY_STATES.has(item.state)) ?? [];
}

/** Prefer preferredId when present in active; otherwise the highest startDate (ties: activityId). */
export function pickDefaultActivity(active, preferredId) {
  if (!active?.length) {
    return null;
  }
  if (preferredId) {
    const match = active.find((item) => item.activityId === preferredId);
    if (match) {
      return match;
    }
  }
  return active.reduce((latest, item) => {
    if (!latest) {
      return item;
    }
    const latestStart = latest.startDate ?? 0;
    const itemStart = item.startDate ?? 0;
    if (itemStart !== latestStart) {
      return itemStart > latestStart ? item : latest;
    }
    return item.activityId > latest.activityId ? item : latest;
  }, null);
}
