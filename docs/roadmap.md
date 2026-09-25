# Roadmap

## Implemented in the local 0.5.0 build

The remaining feature backlog and all four subsequently approved ideas are implemented:

- One running current-version instance across copies, including simultaneous launches and recovery after crashes.
- System light/dark switching through existing saved looks, alongside solar switching.
- Editable toggle and optional snooze, next-favorite, reading-strip movement and presentation shortcuts, with conflict feedback.
- Per-texture intensity recall, optional low-battery threshold and menu-bar favorites.
- Optional static Desk Lamp, with warmth/strength controls and existing overlay visibility rules.
- App-specific saved looks, taking precedence over day/night looks without bypassing exclusions.
- Desk profiles matched to connected displays; global off, display exclusions, snooze and presentation pause remain authoritative.
- A clear reading strip, adjusted in Settings or through optional shortcuts, without pointer monitoring or screen capture.
- Persistent presentation pause, controlled in the menu.
- Pause paths close and discard overlay windows; safe capture/authorization workflows are documented.

The menu holds immediate actions. Settings holds configuration, assignments and bindings. Snooze and presentation controls are not duplicated in Settings.

Existing: all 26 Deckle textures, Soft Wove default, favorites/looks, Shortcuts, fixed/solar schedules, power/display/app rules, Atoll panel handling, imports/library backup, shared Sparkle updates and reviewed diagnostic/crash delivery with GitHub aggregation.

## Validation still requiring physical conditions

- Login startup, Stage Manager and audible VoiceOver: explicitly deferred by the user.
- macOS 13–26, other Apple Silicon machines including base-memory M1, physical external HDR displays and docks: use this Mac only for now; record the untested matrix.
- Whole-device battery discharge: runner prepared; user deferred the idle/unplugged measurement. Prior process-energy measurements are not a battery claim.
- Genuine App Store and Apple Pay authorization, plus specific third-party sharing/recording tools: require the real provider flow. No purchase, credential entry, security bypass or universal capture guarantee is part of acceptance.

Revision-specific local checks are recorded in `outputs/Paper-0.5.0-validation.md`. Earlier 0.3.0 fullscreen/sleep-wake and 0.4.0 physical HDR/input, public artifact and updater results remain historical evidence, not automatic certification of every later build.

Public release/signing-feed acceptance is a separate release task. The new build is local until then.

## Scope boundary

An online gallery, editor, Windows/Intel ports, cosmetic animation/sound and licensing features remain outside the small free macOS scope. The four new ideas above were compared against Paperman's public help/changelog on September 25; this is not a claim about unpublished vendor work.
