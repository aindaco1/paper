# Paper validation

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

September 24, 2026, version 0.1.0 results:

- 42 XCTest tests passed: 22 retained renderer tests, 6 login-service adapter tests, 6 app-state/import/window tests, and 8 schedule/visibility tests. A repeated-hour boundary defect found by the tests was fixed before packaging.
- Platform pin, package versions, vendored-file SHA-256 hashes and documentation checks passed.
- The release app built and launched on an M1 Max with macOS 27.0 (26A428). Its Mach-O declares arm64 and minimum macOS 13.0. Strict code-signature verification passed with the local ad-hoc signature.
- Live settings-window checks passed for master on/off, all three texture choices, intensity, grain, compare, snooze/resume, schedule gating, a display exclusion, power-rule toggles, adding/removing an app exclusion, valid JSON import, invalid-import alerts and removing an imported recipe.
- Imported texture, intensity and grain persisted after relaunch. File pickers were changed to attached sheets after the first UI pass exposed overlapping dialogs; the rebuilt app's sheet and error alert were checked.
- One idle process sample showed 0.0% CPU and approximately 141 MB RSS with settings open. This is a spot check, not a battery-life or sustained-performance measurement.

The UI automation sends actions to individual applications without reliably changing the system foreground app or delivering global hotkeys. App-exclusion activation and shortcut delivery therefore remain manual acceptance items; policy and registration error handling were checked separately. The menu-bar popup, actual login launch, physical power changes, fullscreen coverage, display hot-plug and sleep/wake were not claimed as live passes. Test-only imports and exclusions were removed after inspection. System login and power preferences were not changed.

Version 0.1.1 follow-up:

- 48 XCTest tests passed. New coverage renders and restores each of the ten bundled selections, rejects invalid custom snooze durations, checks next-calendar-day 6 AM across both DST transitions, verifies snooze persistence and remaining pause rules, and checks accessible percentage formatting and readable recipe errors.
- The live texture picker contains all ten choices. Bookcloth was selected and its textured preview inspected. Existing selection, intensity, grain and power/login preferences survived the update.
- The custom snooze sheet disabled submission for 0 and 1,441 minutes, accepted 45 minutes, and displayed the resulting deadline. Ending snooze returned to the existing battery-pause state. Until tomorrow displayed 6 AM. The Mac was already on battery; no physical power transition or system preference was changed.
- The new texture and tomorrow deadline survived another real app relaunch. A malformed JSON file showed the new actionable recipe error. The custom input's accessibility label was present. Test snoozes were cleared and the user's original Soft Wove, 36%, coarse-grain selection restored; power/login preferences were preserved.
- Both interfaces use the same snooze options and PaperCore deadline calculation. The menu-bar popup and physical global shortcut are still manual acceptance items; the settings sheet was exercised live.
- The build script now terminates only this workspace's dist/output copies and verifies the new executable path. The package script derives archive names from the bundle version.

The broader compatibility and notarization limitations above still apply.

Version 0.1.2 follow-up:

- 49 XCTest tests passed. The catalog test renders and restores all 26 pinned Deckle textures. Default/recovery tests check Soft Wove for a fresh installation, unreadable settings, missing textures and removed imports, while preserving valid saved choices.
- The release build passed `--verify`. The live picker listed all 26 textures with Soft Wove first. Slate Veil was selected and its preview inspected, then the user's Soft Wove selection was restored.
- The observed user settings were 34% intensity, coarse grain, enabled overlay, schedule and both power rules off, shortcut on and launch at login on. Those settings were preserved during this update; no system preferences changed.
- The renderer and preset source remain unchanged. Only the catalog exposure and default/fallback selection changed.

Older-OS, hardware, fullscreen and notarization qualification remains outstanding as described above.
