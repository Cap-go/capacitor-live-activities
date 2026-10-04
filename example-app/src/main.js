import './style.css';
import { Capacitor } from '@capacitor/core';
import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { CapgoLiveActivities } from '@capgo/capacitor-live-activities';
import { createDeliveryLayout, deliveryStages } from './activityLayouts.js';

const output = document.getElementById('output');
const support = document.getElementById('support');
const count = document.getElementById('count');
const pushToken = document.getElementById('push-token');
const activityIdLabel = document.getElementById('activity-id');

const actionButtons = ['start', 'update', 'end', 'refresh'].map((id) => document.getElementById(id));
let busy = false;
let activityId = null;
let stageIndex = 0;
let stageRestored = false;

const setOutput = (value) => {
  output.textContent = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
};

async function guarded(fn) {
  if (busy) return;
  busy = true;
  actionButtons.forEach((button) => {
    button.disabled = true;
  });
  try {
    await fn();
  } finally {
    busy = false;
    actionButtons.forEach((button) => {
      button.disabled = false;
    });
  }
}

// Restore the delivery stage from the activity's current data (e.g. after a page reload),
// so Update never moves the demo backward.
function stageIndexFor(activity) {
  const index = deliveryStages.findIndex((stage) => stage.status === activity?.data?.status);
  return index >= 0 ? index : 0;
}

function baseData() {
  return {
    orderNumber: '12345',
    status: deliveryStages[0].status,
    eta: deliveryStages[0].eta,
    progress: deliveryStages[0].progress,
  };
}

async function refresh() {
  const supported = await CapgoLiveActivities.areActivitiesSupported();
  support.textContent = supported.supported ? 'Supported' : `Not supported: ${supported.reason ?? ''}`;

  const activities = await CapgoLiveActivities.getAllActivities();
  const active = activities.activities?.filter((item) => item.state === 'active') ?? [];
  count.textContent = String(active.length);

  // Keep the selection on an active activity; replace a stale or missing selection.
  let selected = active.find((item) => item.activityId === activityId);
  if (!selected && active.length > 0) {
    selected = active[0];
    stageIndex = stageIndexFor(selected);
  } else if (selected && !stageRestored) {
    stageIndex = stageIndexFor(selected);
  }
  stageRestored = true;
  activityId = selected?.activityId ?? null;
  activityIdLabel.textContent = activityId ?? 'None';
  if (!selected) {
    stageIndex = 0;
  }

  // Show the push token of the selected activity only, so it always matches the displayed ID.
  pushToken.textContent = selected?.pushToken ?? 'Not available yet';

  setOutput(activities);
}

document.getElementById('refresh').addEventListener('click', () => {
  guarded(async () => {
    try {
      await refresh();
    } catch (error) {
      setOutput(`Error: ${error?.message ?? error}`);
    }
  });
});

document.getElementById('start').addEventListener('click', () => {
  guarded(async () => {
    try {
      const { layout, dynamicIslandLayout, behavior } = createDeliveryLayout();
      const result = await CapgoLiveActivities.startActivity({
        layout,
        dynamicIslandLayout,
        behavior,
        data: baseData(),
      });
      activityId = result.activityId;
      stageIndex = 0;
      activityIdLabel.textContent = activityId;
      setOutput(result);
      await refresh();
    } catch (error) {
      setOutput(`Error: ${error?.message ?? error}`);
    }
  });
});

document.getElementById('update').addEventListener('click', () => {
  guarded(async () => {
    if (!activityId) {
      setOutput('Start an activity first.');
      return;
    }
    try {
      const nextStageIndex = Math.min(stageIndex + 1, deliveryStages.length - 1);
      const stage = deliveryStages[nextStageIndex];
      await CapgoLiveActivities.updateActivity({
        activityId,
        data: {
          orderNumber: '12345',
          status: stage.status,
          eta: stage.eta,
          progress: stage.progress,
        },
        alertConfiguration: {
          title: 'Delivery update',
          body: stage.status,
        },
      });
      stageIndex = nextStageIndex;
      setOutput({ updated: true, stage });
      await refresh();
    } catch (error) {
      setOutput(`Error: ${error?.message ?? error}`);
    }
  });
});

document.getElementById('end').addEventListener('click', () => {
  guarded(async () => {
    if (!activityId) {
      setOutput('Start an activity first.');
      return;
    }
    try {
      const stage = deliveryStages[deliveryStages.length - 1];
      await CapgoLiveActivities.endActivity({
        activityId,
        data: {
          orderNumber: '12345',
          status: stage.status,
          eta: stage.eta,
          progress: stage.progress,
        },
        dismissalPolicy: 'default',
      });
      activityId = null;
      stageIndex = 0;
      activityIdLabel.textContent = 'None';
      setOutput({ ended: true });
      await refresh();
    } catch (error) {
      setOutput(`Error: ${error?.message ?? error}`);
    }
  });
});

document.getElementById('get-version').addEventListener('click', async () => {
  try {
    setOutput(await CapgoLiveActivities.getPluginVersion());
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
});

guarded(async () => {
  try {
    await refresh();
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
});

if (Capacitor.isNativePlatform()) {
  CapacitorUpdater.notifyAppReady().catch((error) => console.error('Capgo notifyAppReady failed', error));
}
