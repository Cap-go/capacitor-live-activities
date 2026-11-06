#!/usr/bin/env node
/**
 * Ensures npm pack includes widget extension templates shipped for consumer setup.
 */

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const pluginDir = process.cwd();
const required = [
  "package/ios/WidgetExtension/CapgoLiveActivityWidget.template.swift",
  "package/ios/WidgetExtension/LiveActivitiesBundle.template.swift",
];

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "capgo-live-activities-pack-"));
try {
  execFileSync("bun", ["pm", "pack", "--destination", tmpDir, "--quiet"], {
    cwd: pluginDir,
    stdio: "pipe",
  });
} catch (e) {
  console.error("[packed-package] ERROR: bun pm pack failed");
  console.error(e?.stderr?.toString() || e?.message || e);
  process.exit(1);
}

const archives = fs.readdirSync(tmpDir).filter((name) => name.endsWith(".tgz"));
if (archives.length !== 1) {
  console.error(`[packed-package] ERROR: expected one tarball, found ${archives.length}`);
  process.exit(1);
}

const listing = execFileSync("tar", ["-tzf", path.join(tmpDir, archives[0])], {
  encoding: "utf8",
});
const paths = new Set(listing.split("\n").filter(Boolean));

const missing = required.filter((entry) => !paths.has(entry));
if (missing.length) {
  console.error("[packed-package] FAIL: missing paths in packed tarball:");
  for (const entry of missing) console.error(`- ${entry}`);
  process.exit(1);
}

console.log("[packed-package] OK: widget templates present in pack output");
process.exit(0);
