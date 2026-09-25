# Roadmap

Implemented: all 26 Deckle textures, Soft Wove default, favorites/looks, Shortcuts, fixed/solar schedules and solar looks, battery rules, display/app rules, Atoll panel handling, imports and library backup. Version 0.4.0 adds shared Sparkle updates and reviewed diagnostic/crash delivery with GitHub aggregation. Version 0.4.1 simplifies Settings and aligns support actions.

Acceptance completed on M1 Max/macOS 27: the prior 0.3.0 fullscreen and physical sleep/wake checks; 0.4.0 public artifact and signed update/relaunch acceptance; physical toggle, pointer passthrough and visible HDR contrast on the built-in XDR display with measured 16× current headroom. These are distinct revision-specific results. Evidence lives in `outputs/`.

Priorities from the [September 25 Paperman review](paperman-review.md):

1. **One running Paper instance.** Bring the existing app forward when another copy opens. Prevent duplicate overlays and shortcut ownership conflicts; test simultaneous launches and an installed copy alongside a downloaded copy.
2. **Protected UI and capture qualification.** Verify App Store authorization, Apple Pay/Touch ID presentation, system/window screenshots and common screen-sharing paths. Off/snooze/exclusions must remove the windows. Document safe pause workflows; do not bypass protections, add capture/event taps, or promise invisibility to all recorders.
3. **Follow macOS appearance.** Reuse the existing day/night saved looks with a system light/dark trigger, alongside the existing solar option. No separate appearance engine.
4. **Configurable shortcuts.** Start with an editable toggle and conflict feedback. Add optional snooze/next-favorite commands only through the existing state actions.

Complete outstanding integration acceptance for actual login startup, Stage Manager and an audible VoiceOver pass. Expand qualification to macOS 13–26, other Apple Silicon machines including base-memory M1, physical external/HDR displays and docks, and whole-device battery discharge.

Lower priority: per-texture intensity recall, optional low-battery threshold and menu-bar favorite switching, if existing saved looks and battery rules prove insufficient. Desk Lamp-style ambient lighting is optional, not a critical omission. An online gallery, editor, Windows/Intel ports, cosmetic animation/sound and licensing features remain outside the small free macOS scope.
