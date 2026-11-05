#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${REPO_ROOT}"

pick_simulator_name() {
  xcrun simctl list devices available |
    sed -n 's/^[[:space:]]*\(iPhone[^()]*\) (.*/\1/p' |
    head -1
}

SIMULATOR_NAME="$(pick_simulator_name)"
if [[ -z "${SIMULATOR_NAME}" ]]; then
  echo "No available iPhone simulator found on this runner." >&2
  exit 1
fi

DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME}"
echo "Running Swift tests with destination: ${DESTINATION}"

xcodebuild test \
  -scheme CapgoCapacitorLiveActivities \
  -destination "${DESTINATION}" \
  CODE_SIGNING_ALLOWED=NO
