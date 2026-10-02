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

let activityId = null;
let stageIndex = 0;

const setOutput = (value) => {
  output.textContent = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
};

function baseData() {
  return {
    orderNumber: '12345',
    status: deliveryStages[0].status,
    eta: deliveryStages[0].eta,
    progress: deliveryStages[0].progress,
  };
}

async function refresh() {
  try {
    const supported = await CapgoLiveActivities.areActivitiesSupported();
    support.textContent = supported.supported ? 'Supported' : `Not supported: ${supported.reason ?? ''}`;

    const activities = await CapgoLiveActivities.getAllActivities();
    const active = activities.activities?.filter((item) => item.state === 'active') ?? [];
    count.textContent = String(active.length);

    const token = active.find((item) => item.pushToken)?.pushToken;
    pushToken.textContent = token ?? 'Not available yet';

    if (active.length > 0) {
      activityId = active[0].activityId;
      activityIdLabel.textContent = activityId;
    }

    setOutput(activities);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
}

document.getElementById('refresh').addEventListener('click', refresh);

document.getElementById('start').addEventListener('click', async () => {
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

document.getElementById('update').addEventListener('click', async () => {
  if (!activityId) {
    setOutput('Start an activity first.');
    return;
  }
  try {
    stageIndex = Math.min(stageIndex + 1, deliveryStages.length - 1);
    const stage = deliveryStages[stageIndex];
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
    setOutput({ updated: true, stage });
    await refresh();
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
});

document.getElementById('end').addEventListener('click', async () => {
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

document.getElementById('get-version').addEventListener('click', async () => {
  try {
    setOutput(await CapgoLiveActivities.getPluginVersion());
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
});

refresh();

if (Capacitor.isNativePlatform()) {
  CapacitorUpdater.notifyAppReady().catch((error) => console.error('Capgo notifyAppReady failed', error));
}
