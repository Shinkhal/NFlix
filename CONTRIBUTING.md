# Contributing

Use Node.js 24+ on Linux. Run `npm ci`, `npm test` and `npm start`.
Source lives in `src/`; compiled JavaScript in `out/` is not committed.
Build packages with `scripts/build-release.sh`.

Keep Netflix content sandboxed, with context isolation enabled and Node
integration disabled. Do not add certificate bypasses, `--no-sandbox`, or
unrestricted navigation/permission handlers. Keep the Castlabs runtime pinned
and test its component updater after upgrades.

Report playback issues with OS, GPU/driver, runtime versions and the sanitized
playback diagnostics. Never attach cookies, account information or DRM license
traffic. Test actual playback separately from capability detection.

Keep package.json, the lockfile, AppStream metadata and release tags consistent.
Do not publish a stable release based only on CI or capability checks.
