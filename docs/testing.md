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

The declared deployment floor is macOS 13 with an arm64 binary. Runtime testing on macOS 13/14/15/26 and other Apple Silicon machines, base-memory M1, HDR/EDR, mixed external monitors, fullscreen/Stage Manager, hot-plug, sleep/wake and screen-sharing tools remains required before a broad compatibility claim. Developer ID distribution, notarization and installation from the signed DMG have their own checks.

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

Version 0.2.0 follow-up:

- 60 XCTest tests passed. New coverage checks favorite persistence/catalog completeness, saved appearance restoration without changing visibility rules, stable look identities on replacement, look limits/deletion, old schedule decoding, local solar boundaries, the date line, DST, polar days/nights, missing-city behavior and manual/display precedence.
- The actual Developer ID-signed app passed live favorite/save/apply/remove checks. A saved Soft Wove/34%/coarse-grain look restored all three values after they changed. Favorites appeared first without duplicate catalog entries.
- All five native actions appeared in Shortcuts and ran successfully: Toggle Paper, Set Paper Enabled, Snooze Paper, Select Paper Texture and Apply Paper Look. Texture and saved-look entities resolved in the system picker. The initial ad-hoc build was rejected by macOS 27's App Intents mediator for lacking a team identity; the Developer ID build fixed that runtime failure.
- The city picker resolved London, displayed its local approximate sunrise/sunset, and activated the solar schedule. Missing-city mode paused safely; clearing the city was also tested. The test city, favorite and saved look were removed, and the user's original Soft Wove/34%/coarse appearance and fixed schedule-off/power/login preferences were restored.
- Paper's real executable passed 15 native virtual-display checks with Platform's shared fixture: 1×/2×, right/left/above, a non-16:9 monitor, all-display coverage, exclusions, manual off and live attach/remove. Geometry, opacity and unchanged foreground PID were asserted. Two deterministic oracle tests reject wrong bounds, focus, opacity, duplicate windows and visible excluded/off overlays.
- The shared fixture's three characterization tests passed. AppKit and OwlSwitch's injected Qt enumeration both passed 1×/2× capability checks and exact topology restoration. Platform `npm test` passed, as did OwlSwitch's five existing regression-oracle tests.
- The migrated OwlSwitch full-app suite passed all 18 cases against the supplied existing app: ten cold starts, delayed switching, cancellation, same-screen playback, the negative control, Retina, letterboxed, left and above layouts. Exact original topology restoration was confirmed after every fixture. Earlier runs exposed desktop focus interference (one recorded interruption was Record taking the foreground); the final idle-desktop rerun passed without changing assertions. The migration remains an isolated local branch with rollback instructions, not a published OwlSwitch release.
- Developer ID signing, Apple notarization acceptance, ticket stapling and Gatekeeper acceptance were exercised for Paper.app. Final packaged app/DMG receipts and native evidence are delivered alongside the app in outputs.

The test harness accepts only UUID-named disposable preferences suites. A distinct test opacity proves isolation; only test-owned processes are stopped and UUID-domain data is cleared. It does not modify login items or power preferences and takes no screenshots. Native helpers are test-only, separately GPL-3.0-licensed, and excluded from the MIT application.

The virtual suite does not qualify fullscreen Spaces, physical click-through, HDR/EDR, actual monitor firmware/cables, sleep/wake, or all macOS 13+ hardware. Those remain manual/physical acceptance work. Notarization is a trust/distribution check, not hardware compatibility proof.

Version 0.2.1 follow-up:

- Fixed nonactivating floating-panel exclusions. Atoll's bundle identifier was saved correctly, but its visible notch panel did not change the foreground app. Its window was at level 27 while Paper was at 1000. Paper now draws at 26 beneath that excluded panel, preserving the 34% texture across ordinary windows. Foreground-app exclusions still pause the entire overlay; manual off and display exclusions retain priority.
- A narrow adapter checks public on-screen window metadata only while an excluded app is running and Paper is enabled. It suspends during sleep/session inactivity, ignores hidden apps and transparent windows, and changes state only when panel levels change. No screenshots, window titles, event taps or new permissions are used.
- 62 XCTest tests and all 18 native display checks passed. The native suite includes a real nonactivating accessory-panel fixture and verifies excluded/unexcluded stacking plus restoration after the excluded app exits. The oracle rejects incorrect levels instead of merely accepting the presence of an overlay.
- The user's Atoll exclusion, Soft Wove at 34%, coarse grain, schedule-off and power/login settings are preserved. Updated signed/notarized app and DMG evidence accompanies the 0.2.1 delivery.


Version 0.3.0 follow-up:

- Added selected-app mode, automatic day/night saved looks, display intensity overrides and an atomic library backup/merge. Manual off, excluded displays and other visibility rules retain priority. Legacy settings migrate with the new features disabled by default.
- 74 XCTest cases cover the new policy, migration, automatic appearance, hostile/bounded JSON, collision remapping, idempotent imports, corruption and capacity handling alongside the retained Deckle/Record suites.
- The live app passed automatic-look selection with effective intensity, a display override/reset, empty selected-app pause, library export/reimport without duplicates and manual-look restoration. Temporary looks/city were removed; Atoll and user appearance/power/login preferences were retained.
- 23 native display cases passed, including different global/virtual-display opacities and only-app precedence. Six additional checks passed in actual native fullscreen Spaces: before/during/after, manual off, foreground exclusion and display exclusion. Final artifact hashes are recorded in delivered JSON.
- The broad review fixes and measurement limitations are described in [performance and security review](performance-security.md). Real sleep/wake was initially blocked by the host's system-wide SleepDisabled setting; no physical success is inferred from notification-policy unit tests. The delivery report records final physical-test and sustained-measurement outcomes.
