# Paper

Paper is a small local macOS 13+ menu-bar application for Apple Silicon.

- Keep the interface focused: textures, intensity, schedule, battery rules, imports and exclusions.
- Use the pinned Deckle renderer and Record login adapter; preserve their licenses and provenance.
- Pure visibility and schedule policy belongs in PaperCore. Keep Apple system APIs in narrow adapters.
- Do not capture screens, install event taps, alter display gamma, add telemetry or introduce a custom updater.
- Overlay windows never take focus or intercept input. Manual off and display exclusions always win.
- Do not claim an overlay can hide from all recording tools.
- Platform is pinned for developer tooling. Do not add unrelated speech/AI dependencies.
- Run `node script/validate.mjs`, `swift test`, and `./script/build_and_run.sh --verify` for functional changes.
- Use the real app for UI acceptance. Unit tests do not prove fullscreen, hardware or release compatibility.
- Build artifacts stay in dist/; user deliverables go in outputs/. No releases or public uploads without a release task.

