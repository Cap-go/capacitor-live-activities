import { describe, expect, test } from 'bun:test';
import {
  filterSelectableActivities,
  pickDefaultActivity,
  SELECTABLE_ACTIVITY_STATES,
} from './activitySelection.js';

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

describe('pickDefaultActivity', () => {
  test('returns preferred id when still active', () => {
    const active = [
      { activityId: 'older', startDate: 1 },
      { activityId: 'newer', startDate: 2 },
    ];
    expect(pickDefaultActivity(active, 'older')?.activityId).toBe('older');
  });

  test('falls back to highest startDate when preferred is missing', () => {
    const active = [
      { activityId: 'a', startDate: 100 },
      { activityId: 'b', startDate: 200 },
    ];
    expect(pickDefaultActivity(active, 'gone')?.activityId).toBe('b');
  });
});
