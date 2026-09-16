#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
case "$platform" in
  android | ios | web) ;;
  *)
    echo "Usage: $0 <android|ios|web>"
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_root="${RUNNER_TEMP:-$(mktemp -d)}"
pack_dir="$tmp_root/plugin-package"
test_app="$tmp_root/plugin-example-app"

cd "$repo_root"

bun run build

rm -rf "$pack_dir" "$test_app"
mkdir -p "$pack_dir" "$test_app"
bun pm pack --destination "$pack_dir" --quiet

shopt -s nullglob
packed_packages=("$pack_dir"/*.tgz)
shopt -u nullglob
if [ "${#packed_packages[@]}" -ne 1 ]; then
  echo "Expected exactly one package tarball, found ${#packed_packages[@]}"
  exit 1
fi

plugin_name="$(bun -e 'console.log(require("./package.json").name)')"
cp -R example-app/. "$test_app/"
cd "$test_app"
bun remove "$plugin_name"
bun add "${packed_packages[0]}"
bun run build

add_example_post_notifications() {
  local manifest="android/app/src/main/AndroidManifest.xml"
  if [ ! -f "$manifest" ]; then
    echo "Expected $manifest after cap add android"
    exit 1
  fi
  python3 - "$manifest" <<'PY'
from pathlib import Path
import sys

manifest = Path(sys.argv[1])
text = manifest.read_text()
perm = "android.permission.POST_NOTIFICATIONS"
app_idx = text.find("<application")
if app_idx < 0:
    raise SystemExit(f"No <application> in {manifest}")
if perm in text and text.find(perm) < app_idx:
    raise SystemExit(0)
text = text.replace(
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n',
    "",
)
app_idx = text.find("<application")
injection = f'    <uses-permission android:name="{perm}" />\n\n'
manifest.write_text(text[:app_idx] + injection + text[app_idx:])
print(f"Added POST_NOTIFICATIONS before <application> in {manifest}")
PY
}

bump_example_ios_16() {
  local ios_pbxproj="ios/App/App.xcodeproj/project.pbxproj"
  local ios_podfile="ios/App/Podfile"
  local ios_spm="ios/App/CapApp-SPM/Package.swift"
  if [ -f "$ios_pbxproj" ]; then
    sed -i.bak 's/IPHONEOS_DEPLOYMENT_TARGET = 15.0/IPHONEOS_DEPLOYMENT_TARGET = 16.0/g' "$ios_pbxproj"
    rm -f "${ios_pbxproj}.bak"
  fi
  if [ -f "$ios_podfile" ]; then
    sed -i.bak "s/platform :ios, '15.0'/platform :ios, '16.0'/g" "$ios_podfile"
    rm -f "${ios_podfile}.bak"
  fi
  if [ -f "$ios_spm" ]; then
    sed -i.bak 's/\.iOS(\.v15)/.iOS(.v16)/g' "$ios_spm"
    rm -f "${ios_spm}.bak"
  fi
}

case "$platform" in
  android)
    if [ ! -d android ]; then
      bunx cap add android
    fi
    bunx cap sync android
    add_example_post_notifications
    cd android
    ./gradlew build test
    ;;
  ios)
    if [ ! -d ios ]; then
      bunx cap add ios
    fi
    bump_example_ios_16
    bunx cap sync ios
    bump_example_ios_16
    rm -rf "$HOME/Library/Caches/org.swift.swiftpm/artifacts"/https___github_com_ionic_team_capacitor_swift_pm_releases_download_*
    xcodebuild \
      -project ios/App/App.xcodeproj \
      -scheme App \
      -destination generic/platform=iOS \
      -clonedSourcePackagesDirPath "$tmp_root/plugin-example-swiftpm" \
      -derivedDataPath "$tmp_root/plugin-example-derived-data" \
      CODE_SIGNING_ALLOWED=NO
    ;;
  web)
    ;;
esac
