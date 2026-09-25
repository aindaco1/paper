# Paper 0.3.0 performance and security review

Scope: the local Swift/AppKit app, imported JSON, preferences, window rules,
renderer/cache call sites, App Intents, native adapters, and local release scripts.
This is a source review plus targeted runtime testing, not an external penetration
test or proof of compatibility with every supported Mac/macOS release.

## Changes made

- File imports now bound the actual read to 1 MB. Opening nonblocking and checking
  the descriptor rejects pipes, directories and oversized/growing files without
  following a size-check-then-unbounded-read path. Recipes reject nonfinite
  parameters and sanitize names before reaching the pinned, range-clamped renderer.
- Library backups use a fixed format/version, bounded item counts, unique IDs,
  validated references and appearance values. Collision remapping preserves look
  and favorite references. The merge validates completely before persistence;
  recipes and library metadata commit as a single preferences snapshot.
- Legacy library data is validated on load. Corruption recovery keeps one latest
  local backup per key instead of accumulating a new copy every launch. Unreadable
  visibility settings leave Paper off until explicitly enabled again.
- Floating-panel polling stops whenever the overlay cannot be shown: snooze,
  app/schedule/power pauses, all displays excluded, manual off, sleep or inactive
  session. It restarts on state/workspace events; visible excluded panels still
  use the existing 0.5-second check. Self windows are ignored.
- A foreground app without a bundle ID now clears the last app identity, so
  selected-app mode cannot keep showing a texture based on stale information.
  Wake refreshes the foreground app. Space-change notifications no longer clear
  sleep/session guards; waking also does not bypass an inactive session.

## Retained boundaries

No screen capture, window titles, event taps, gamma changes, telemetry, custom
updater, network listener, shell execution, or new runtime dependency was added.
The app uses public on-screen window metadata for panel stacking. Carbon registers
only the explicit hotkey. The global off/display exclusions remain authoritative.

City lookup sends the explicitly entered city to Apple's geocoder. Subsequent
solar calculations are local, without device-location permission. Library backups
contain custom papers, favorites and looks; they omit city, application rules,
display identities, login settings and credentials. Preferences are local user
data, not a security boundary against another process running as the same user.

Deckle and Record source/license hashes and the Platform tooling pin are verified
by the existing validator. Rendering stays on the main actor and caches retain
Deckle's bounded capacities (16 fields, 16 tiles, eight composites, 24 previews).
The renderer itself remains unchanged. Native test helpers are never bundled.

## Evidence and limits

`swift test` exercises corrupt settings, bounded reads (including a FIFO), hostile
JSON, missing/duplicate references, capacity failures, collision remapping and
idempotence, old preferences, only-app precedence, display overrides and automatic
look transitions. Existing cache stress and pixel-fidelity tests remain in place.

The actual release build is checked by the shared Platform display fixtures and a
real AppKit fullscreen Space fixture. The UI was exercised for automatic looks,
display intensity, empty selected-app mode, library export/reimport and manual
appearance restoration. Test data is removed while preserving the user's Atoll
exclusion and appearance.

See the delivered `Paper-performance-security.md` and JSON reports for measured
CPU, wakeups, memory and process energy, including exact executable hashes. The
first 0.3.0 paused measurement was contaminated by UI and display-test activity
and is excluded from the comparison. The clean measurements run serially with
settings closed. No system power/security settings are changed for measurement.

Kernel `ri_energy_nj` measures process-attributed energy. It excludes WindowServer,
the display/GPU and other applications and does not quantify battery drain or
whole-system power. Administrator-only `powermetrics` was unavailable. Cold/warm
renderer measurements use optimized code; timing is reported rather than used as
an unstable correctness threshold.

Physical sleep/wake requires actual system events and a person to unlock the Mac.
The host initially reported `SleepDisabled = 1`; `pmset sleepnow` returned
`0xe00002e2` and a manual observation window saw no sleep notification. Those
attempts are blocked tests, not passes. Consult the final delivery report for any
subsequent successful cycle. macOS 13 through 26, other Apple Silicon models,
physical external displays, HDR/EDR and extended battery discharge remain outside
this host's measured acceptance.
