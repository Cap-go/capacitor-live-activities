#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${REPO_ROOT}"

# Prefer an available iPhone simulator and pin DESTINATION by UDID so xcodebuild
# does not default OS=latest against a device that only exists on an older runtime.
pick_simulator_id() {
  xcrun simctl list devices available |
    sed -n 's/^[[:space:]]*iPhone[^()]* (\([A-F0-9-]*\)) .*/\1/p' |
    head -1
}

SIMULATOR_ID="$(pick_simulator_id)"
if [[ -z "${SIMULATOR_ID}" ]]; then
  echo "No available iPhone simulator found on this runner." >&2
  exit 1
fi

DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"
echo "Running Swift tests with destination: ${DESTINATION}"

xcodebuild test \
  -scheme CapgoCapacitorLiveActivities-Package \
  -destination "${DESTINATION}" \
  CODE_SIGNING_ALLOWED=NO
