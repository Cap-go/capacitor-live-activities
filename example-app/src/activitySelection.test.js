import { describe, expect, test } from 'bun:test';
import { filterSelectableActivities, SELECTABLE_ACTIVITY_STATES } from './activitySelection.js';

describe('filterSelectableActivities', () => {
  test('includes active and stale activities', () => {
    const activities = [
      { activityId: 'a', state: 'active' },
      { activityId: 'b', state: 'stale' },
      { activityId: 'c', state: 'ended' },
    ];
    expect(filterSelectableActivities(activities).map((item) => item.activityId)).toEqual(['a', 'b']);
  });

  test('selectable states match ActivityKit ongoing activities', () => {
    expect(SELECTABLE_ACTIVITY_STATES.has('stale')).toBe(true);
    expect(SELECTABLE_ACTIVITY_STATES.has('dismissed')).toBe(false);
  });
});
