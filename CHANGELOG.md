# Changelog

## 1.0.3 - 2026-09-25

- Keep the texture visible while revealing the Dock or using Command-Tab. Distinguish their full-display backdrops from Mission Control overview surfaces, with policy and real-desktop regression coverage.

## 1.0.2 - 2026-09-25

- Hide the overlay during Mission Control so Spaces previews stay readable, and restore the texture promptly on exit. Preserve fullscreen support and pause rules, including repeated overview entry.

## [1.0.1] - 2026-09-25

- Adopt the shared Apple support core through the compatible desktop diagnostics API. Preserve reviewed reports, explicit sending, update consent and existing app behavior.

## 1.0.0 - 2026-09-25

- Add system-appearance and app-specific saved looks, display-matched desk profiles, and per-texture intensity recall.
- Add menu-only presentation pause and reading-strip toggling, favorite selection, configurable shortcuts and conflict feedback.
- Add static Desk Lamp controls and optional low-battery threshold.
- Enforce one instance across app copies and discard overlay windows while paused.
- Extend policy, native workflow and hardware qualification tooling; keep deferred physical checks explicit.

## 0.4.2 - 2026-09-25

- Share the existing shared desktop package, advanced to version 0.2.0 through the pinned Dust Wave Platform dependency. Preserve existing update consent and product-specific diagnostics behavior. See the [migration record](docs/SHARED_DESKTOP_MIGRATION.md).

## 0.4.1

- Simplify Settings: use the main toggle to compare, and keep Snooze in the menu bar.

- Align Help & diagnostics actions in one footer with consistent control sizing, and wrap support/privacy text without truncation.

## 0.4.0

- Add standard signed Sparkle updates through Platform's separate desktop package, automatic-check preference and manual checking.
- Add reviewed, privacy-filtered logs and Paper crash summaries with local export, explicit GitHub submission and shared issue aggregation.
- Keep update installation pending while a report is being sent; preserve report IDs for retry.
- Keep login launches in the menu bar and preserve explicit reopen behavior.
- Add CI, contribution/privacy/release documentation and a static physical HDR/input fixture.

## 0.3.0

Selected-app mode, automatic day/night looks, display intensity overrides, atomic library backup and bounded import/persistence hardening. Native fullscreen and physical sleep/wake passed on the tested M1 Max.
