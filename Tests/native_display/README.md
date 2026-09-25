# Native Paper display checks

Run serially on an idle, logged-in macOS desktop:

```sh
python3 -m unittest discover -s Tests/native_display -p 'test_*.py'
python3 Tests/native_display/regression.py --app dist/Paper.app --evidence dist/paper-native-display.json
```

Quit the ordinary Paper instance first. The suite launches the actual supplied
app; it never re-signs it. Every case uses a disposable UUID preferences suite,
with a distinctive intensity checked by the oracle. `PAPER_TEST_SUITE` is the
single opt-in storage seam; normal launches use the user's standard preferences.
Foundation's test-home override did not isolate preferences on the local macOS 27
host, so the harness does not rely on it. The suite clears only its own UUID
domains after terminating its app processes, then verifies that they contain no data.
macOS may retain empty preferences-domain files. Login preferences are never changed.

Twenty-three checks cover 1×/2× monitors, right/left/above positions, non-16:9 geometry,
all-display coverage, per-display exclusion and intensity, selected-app policy, manual off, and adding/removing a
monitor while Paper runs. A test-only accessory app also checks nonactivating floating
panels with and without exclusion, plus normal stacking after it quits. Every visible overlay must match a display within one
logical point, have the expected opacity and window level, and leave the foreground PID unchanged.
Deliberately wrong geometry, focus, opacity and duplicate-window fixtures verify
the failure oracle. Evidence includes the supplied executable hash and topology.

Platform `tools/macos-display` 0.1.0 owns compilation, virtual-display lifetime,
the cross-consumer desktop lock and topology restoration. AppKit enumeration is
the default; OwlSwitch injects its Qt enumerator. Unsupported private APIs or
missing WindowServer prerequisites fail explicitly. No screenshot is captured.

The harness uses existing Accessibility permission for window/focus inspection;
it does not request or change permissions. The product itself does not need it.
These tests do not prove pointer passthrough, fullscreen Spaces, physical HDR/EDR,
mixed physical monitors, hardware hot-plug, sleep/wake or older macOS acceptance.
Those remain manual/physical acceptance work. A passing virtual suite is not a
claim that every Apple Silicon Mac is qualified.

This test driver and the OwlSwitch-derived fixture are GPL-3.0; see the fixture's
LICENSE. They are excluded from Paper.app. The application remains MIT-licensed.

## Fullscreen and real sleep/wake

```sh
python3 Tests/native_display/fullscreen.py --app dist/Paper.app --evidence outputs/Paper-fullscreen.json
python3 Tests/native_display/sleep_wake.py --app dist/Paper.app --evidence outputs/Paper-sleep-wake.json --trigger work/sleep-authorized.trigger
```

The fullscreen fixture activates a real AppKit window and enters/exits native
fullscreen Spaces, asserting six app cases. It restores the previous foreground
app and closes its test window. This deliberately changes Spaces during the test.

Sleep testing is disruptive: coordinate a person to wake and unlock the Mac.
Wait for READY, then create the trigger file only when that person is ready.
The script observes actual workspace sleep/wake notifications and checks active,
manual-off and excluded-display cases before and after. `--manual` uses the Apple
Sleep menu instead of `pmset sleepnow`. A timeout or a host with system sleep
disabled is a failure/blocker, never a physical pass. Do not change system power
settings or enable administrator access as an implicit test setup step.

## Physical HDR and input

Compile `HDRFixture.swift` as a test-only AppKit executable, then pass an absolute JSONL evidence path when launching it. It renders static extended-linear-sRGB float patches at 0.18, 1, 2 and 4 using `CAMetalLayer`; it never changes brightness, color presets, gamma or power settings. Bring its window to the foreground and allow HDR headroom to settle, then use **Record HDR state**. Compare Paper on/off using the physical shortcut and click **Click-through test** with the real pointer. The evidence records headroom, focus and click counts, without screenshots.

Physical observer feedback establishes whether bright patches remain distinct; an SDR screenshot cannot. Current headroom of 1 is inconclusive for HDR, even when potential headroom is greater. Power mode, content visibility and the display preset can affect it. Record those limitations instead of calling capability a pass.

## 0.5 workflow checks

```sh
python3 Tests/native_display/workflows.py --app dist/Paper.app --evidence outputs/Paper-workflows.json
```

Uses the same Platform metadata-only probe and serial desktop lock. Checks static
lamp/strip overlays, absence of paused windows (including transparent ones), copied
app ownership, simultaneous cold launches and recovery after killing the owner.
The copies retain the supplied signature. It never changes the user's settings.

`InteractionFixture.swift` provides a local click counter and a cancellable system
LocalAuthentication prompt. Its prompt auto-cancels after 20 seconds; no purchase,
credential or actual biometric is needed. Compile it only into a test app, pause
Paper first, inspect the prompt and cancel it. This is not App Store/Apple Pay or
third-party screen-sharing qualification.
