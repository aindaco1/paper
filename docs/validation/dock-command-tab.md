# Dock and Command-Tab regression fix

Local source validation on September 25, 2026, M1 Max / macOS 27.0 (26A428).
This records the source fix before the 1.0.3 version bump. Dependencies and vendor
sources are unchanged; release artifact acceptance is recorded separately.

## Cause and change

The 1.0.2 Mission Control detector treated a full-display Dock window at layer 20
as an overview. On this host, revealing the auto-hidden Dock and holding
Command-Tab both create that surface. The new native regression reproduces the
missing overlay in the installed 1.0.2 app for both interactions, twice each.

Mission Control has a distinct full-display WindowManager surface at layer 19
on this host. The adapter now resolves both system processes by bundle identifier
and passes public ownership/layer/alpha/bounds metadata to `SystemOverviewPolicy`
in PaperCore. That policy accepts the WindowManager overview surface and the
older Dock overview surface at layer 18, while rejecting ordinary layer-20 Dock
and app-switcher backdrops. It continues to inspect current on-screen windows,
so repeated entry does not depend on a cached window ID.

The APIs are public [Core Graphics window metadata](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)).
The owner/layer patterns are empirical, not a documented Mission Control status
API. The older Dock pattern has deterministic coverage; older macOS runtime
acceptance is still required. No title reading, screen capture, event taps, new
product permissions or runtime dependencies are introduced. Existing eligibility,
sleep/session, off, pause and exclusion gates remain in force.

## Regression coverage

- Six Swift policy tests cover both reported false positives, overview ownership
  and layer, repeated transitions, offset displays, rounding and invalid surfaces.
- The native Dock/switcher suite uses the actual supplied app and isolated
  preferences. It independently confirms the real interaction through Accessibility,
  samples every overlay state throughout each hold, and verifies the interaction
  stayed open. Temporary disappearance fails even if the texture later returns.
- Two new Python oracle tests check uninterrupted visibility and ensure a
  visible/hidden/visible sequence fails. All four Python oracle tests pass in the
  existing CI discovery command; Swift tests also run in existing CI. The desktop
  interaction suites run separately on an idle logged-in Mac.

See [native test instructions](../../Tests/native_display/README.md) for commands,
input cleanup and permissions. The test helpers are never bundled in Paper.

## Current local evidence

- Platform pin, vendor hashes and documentation validation passed.
- 97 Swift tests passed using `swift test --build-system native`. The default
  Swift Build backend hit generated-test-bundle Finder metadata from iCloud;
  the native backend ran the same complete XCTest suite successfully.
- Four Python oracle tests and four relay contract tests passed.
- `./script/build_and_run.sh --verify` built, signed and launched the local app.
- All 27 native Dock/Command-Tab checks passed, including repeated interactions,
  restoration, manual off, display exclusions and unchanged foreground focus.
- All 11 Mission Control, six fullscreen and 23 display/floating-panel checks
  passed: 67 native checks total on the same executable. An initial Mission Control
  run stopped when UserNotificationCenter stole focus; the complete clean repeat
  passed without relaxing the assertions.
- Local machine-readable evidence is in `outputs/Paper-dock-fix-validation.json`
  and its four referenced suite reports. Every report matches executable SHA-256
  `c9714b5d724148c11b73641a840b8e0bd8fdc0e196ec362b8b4af3c13398a253`.

These are local behavior/metadata checks, not notarization, update installation,
thumbnail pixel inspection or qualification of other OS versions/hardware.
