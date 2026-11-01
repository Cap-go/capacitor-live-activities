/** Activity states the demo can select for Update and End. */
export const SELECTABLE_ACTIVITY_STATES = new Set(['active', 'stale']);

export function filterSelectableActivities(activities) {
  return activities?.filter((item) => SELECTABLE_ACTIVITY_STATES.has(item.state)) ?? [];
}
