import './style.css';
import { Capacitor } from '@capacitor/core';
import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { CapgoLiveActivities } from '@capgo/capacitor-live-activities';

const output = document.getElementById('output');
const support = document.getElementById('support');
const count = document.getElementById('count');
const setOutput = (value) => {
  output.textContent = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
};

async function refresh() {
  try {
    const supported = await CapgoLiveActivities.areActivitiesSupported();
    support.textContent = supported.supported ? 'Supported' : 'Not supported';
    const activities = await CapgoLiveActivities.getAllActivities();
    count.textContent = String(activities.activities?.length ?? 0);
    setOutput(activities);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
}

document.getElementById('refresh').addEventListener('click', refresh);
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
