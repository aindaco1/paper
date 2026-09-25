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

Fifteen checks cover 1×/2× monitors, right/left/above positions, non-16:9 geometry,
all-display coverage, per-display exclusion, manual off, and adding/removing a
monitor while Paper runs. Every visible overlay must match a display within one
logical point, have the expected opacity, and leave the foreground PID unchanged.
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
