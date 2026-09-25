# Shared desktop services migration

Source migration only; release and deployment acceptance remain separate.

- Consumer baseline: `384af16c6a719f8644ecd82126d64a2abb8a4c9f`.
- Previous Platform pin: `2054aaec3264393390577c70cb0a084a256a835c`.
- New immutable commit and exact versions: [platform-desktop.json](../platform-desktop.json).
- Shared surface: The existing shared desktop package, advanced to version 0.2.0.

Keep Paper's explicit launch call, automatic-check preference, reviewed preview and pending report handling. Sparkle stays exactly 2.10.0.

## Validation

Before: diagnostics characterization passed. After: `node script/validate.mjs`, `swift test`, and `./script/build_and_run.sh --verify` passed. The last command confirms local build and launch only.

All consumer gitlinks, exact package versions and retained Sparkle lockfile
revisions pass:

```sh
node shared/dust-wave-platform/scripts/check-desktop-consumer.mjs
```

Platform passes its JavaScript suite and clean-checkout recipe tests. Its seven
desktop Swift tests pass independently with Sparkle 2.9.5, 2.9.6 and 2.10.0.
App manifests retain their exact existing Sparkle revisions. Advancing the
full gitlink also carries existing Platform patches; product-owned tests
cover those dependencies.

## Independent rollback

Revert this repository's migration commit, then run
`git submodule update --init --recursive`. This restores the prior adapters,
dependency declaration, gitlink and build/CI configuration together. For a
newly added Platform submodule, Git may leave an untracked checkout directory;
it is no longer a build input after the revert.

No user data or relay storage migration is required. Other applications may
stay on their chosen Platform revisions. A reverse-patch check of the complete
migration records whether the source rollback applies cleanly.

Local source/build evidence does not establish notarization, a signed updater
replacement, physical hardware behavior or deployed GitHub delivery. Use the
existing release runbook before shipping.
