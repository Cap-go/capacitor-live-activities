import { registerPlugin } from '@capacitor/core';

import type { CapgoLiveActivitiesPlugin } from './definitions';

const CapgoLiveActivities = registerPlugin<CapgoLiveActivitiesPlugin>('CapgoLiveActivities', {
  web: () => import('./web').then((m) => new m.CapgoLiveActivitiesWeb()),
});

export * from './definitions';
export { CapgoLiveActivities };
