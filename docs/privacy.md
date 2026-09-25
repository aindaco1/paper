# Privacy and diagnostics

Paper renders local texture tiles. It does not capture screens, install event taps, adjust gamma, or send telemetry. Recipes, looks and visibility rules stay on the Mac. City lookup sends the entered city to Apple's geocoding service.

Sparkle checks the official GitHub release feed at launch and periodically when automatic checks are enabled. Checks can be disabled in settings; manual checks remain available. Installation requires user action. System profiling and automatic installation are disabled. Connections expose ordinary provider connection metadata; Paper does not add a device identifier.

**Help & diagnostics** prepares an exact JSON preview. Only numeric app/build/OS versions, architecture, broad overlay/power/schedule state, coarse intensity, bounded display counts and the last 20 event categories are included. Event categories never carry arbitrary messages. Reports exclude paths, application names and IDs, display IDs, city, recipe names/content, saved looks, credentials, stack symbols, raw crash reports and environment variables. A bounded event journal and one pending filtered report are kept in the local Paper preferences domain. A report ID identifies a retryable submission, not a person or device.

**Import crash log** accepts a user-selected Paper `.ips` file up to 2 MB. The shared native parser checks its product identity and retains only allowlisted exception/signal/image, a bounded image offset and incident versions. The incident's build and OS govern grouping; current settings do not split identical crashes. The raw incident stays local.

**Send to public GitHub issues** is an explicit action. It sends the displayed report, at most 8 KiB, over HTTPS to `https://crash.dustwave.xyz/v1/paper/reports`. The existing relay holds GitHub credentials and creates or updates an issue only in `aindaco1/paper`. Identical fingerprints share an issue; retries retain their ID and do not increment the count twice within the relay's bounded receipt retention. Opening the sheet, importing a crash or saving JSON does not upload it. No report is automatically sent after a crash.

The transport rejects redirects, oversized replies and mismatched acknowledgements. Failed/unconfirmed sends remain retryable. GitHub issues are public; use the [private security channel](../SECURITY.md) for vulnerabilities. Relay IP rate limits use connection metadata for abuse prevention, never issue content. Counts are submissions, not unique users or proven root causes.

Desk profiles, per-app look assignments, shortcut bindings, texture intensity recall,
reading-strip geometry and lamp settings remain in local preferences. None are
added to diagnostic reports. Presentation/low-battery pauses map to the existing
coarse snooze/battery categories of the deployed report schema. The reading strip
uses fixed user-chosen geometry, without pointer monitoring or screen analysis.
The instance coordinator accepts only a request to show Settings; it has no remote
configuration, file-opening or command-execution protocol.
