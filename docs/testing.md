# Paper 0.1.0 validation

This file separates automated evidence, local app acceptance and broader release qualification.

Automated coverage includes the retained Deckle renderer suite and Record login-service tests, plus Paper's schedule boundaries, DST behavior, snooze expiry, manual-off/display/app/power precedence, corrupt-data recovery, recipe identity/seed compatibility, partial import failures, and overlay window input/focus configuration.

Run:

```sh
node script/validate.mjs
swift test
./script/build_and_run.sh --verify
```

Local UI checks should exercise the actual bundled application: toggle, texture/intensity changes, compare, snooze/resume, a display exclusion, app exclusion, schedule gating, valid/invalid recipe imports, persistence after relaunch, the global shortcut, and clean quit. Do not toggle launch at login or change system battery settings merely to make a test pass; use the adapter/policy tests for those paths and mark real system acceptance separately.

The declared deployment floor is macOS 13 with an arm64 binary. Runtime testing on macOS 13/14/15/26 and other Apple Silicon machines, base-memory M1, HDR/EDR, mixed external monitors, fullscreen/Stage Manager, hot-plug, sleep/wake and screen-sharing tools remains required before a broad compatibility claim. Developer ID distribution, notarization and a real signed-update installation are separate release work.

September 24, 2026 results:

- 42 XCTest tests passed: 22 retained renderer tests, 6 login-service adapter tests, 6 app-state/import/window tests, and 8 schedule/visibility tests. A repeated-hour boundary defect found by the tests was fixed before packaging.
- Platform pin, package versions, vendored-file SHA-256 hashes and documentation checks passed.
- The release app built and launched on an M1 Max with macOS 27.0 (26A428). Its Mach-O declares arm64 and minimum macOS 13.0. Strict code-signature verification passed with the local ad-hoc signature.
- Live settings-window checks passed for master on/off, all three texture choices, intensity, grain, compare, snooze/resume, schedule gating, a display exclusion, power-rule toggles, adding/removing an app exclusion, valid JSON import, invalid-import alerts and removing an imported recipe.
- Imported texture, intensity and grain persisted after relaunch. File pickers were changed to attached sheets after the first UI pass exposed overlapping dialogs; the rebuilt app's sheet and error alert were checked.
- One idle process sample showed 0.0% CPU and approximately 141 MB RSS with settings open. This is a spot check, not a battery-life or sustained-performance measurement.

The UI automation sends actions to individual applications without reliably changing the system foreground app or delivering global hotkeys. App-exclusion activation and shortcut delivery therefore remain manual acceptance items; policy and registration error handling were checked separately. The menu-bar popup, actual login launch, physical power changes, fullscreen coverage, display hot-plug and sleep/wake were not claimed as live passes. Test-only imports and exclusions were removed after inspection. System login and power preferences were not changed.
