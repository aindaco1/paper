# Support

Check [existing issues](https://github.com/aindaco1/paper/issues) first. Include the Paper/macOS versions, what you expected and reproducible steps. Avoid personal data.

Use **Help & diagnostics…** from settings or the menu bar. Review the JSON, save it locally, or explicitly send it to the public repository. Matching reports join an existing issue. The result includes a link only after delivery is confirmed. If sending fails, retry the same preview; Refresh creates a new submission ID. A user-selected Paper `.ips` incident can be projected into a crash summary. Raw logs and full incidents are not uploaded.

For security issues use [private reporting](../SECURITY.md), not the public-report button.

## Presentations, capture and protected dialogs

Choose **Pause for presentation** in the menu before sharing/capturing or opening a protected authorization prompt. Its pause survives app switching, timed snooze expiry and relaunch. **End presentation pause** restores the texture only when all other rules allow it. Ordinary off, snooze and app/display exclusions also close and discard the overlay windows; these are explicit pause workflows, not automatic meeting or recording detection.

For App Store or Apple Pay authorization, pause first, then open/retry the real provider prompt. Cancel if you only intend to test presentation. Never enter credentials or authorize a payment just to complete Paper testing. A cancellable LocalAuthentication fixture is useful evidence for that system dialog only; it does not qualify Apple Pay or App Store provider behavior.

Window screenshots, full-display captures and sharing apps can compose overlays differently. Paper does not claim to hide from capture. Verify the desired source in the recorder/sharing preview after pausing, before starting a real recording or broadcast.
