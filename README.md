# Nflix Desktop

An unofficial Linux desktop app that opens Netflix in a dedicated, sandboxed
Castlabs Electron window. The application is written in TypeScript.

Nflix Desktop is not affiliated with or endorsed by Netflix. A Netflix account
and internet connection are required. The app does not provide content or
offline downloads.

## Run from source

Use Linux x86_64 with Node.js 24 or newer and npm.

```sh
npm ci
npm start
```

The runtime is pinned to Castlabs Electron 45.2.1+wvcus. It obtains Widevine
through its component updater, waits for setup, and restarts once when necessary
to activate a newly installed component on Linux. Initial setup needs network
access. The app does not copy a CDM from Chrome or Firefox.

## Playback status

**Netflix video and sound were confirmed working by the user on 2026-11-24**
in the installed 0.3.0 build on Fedora 45 x86_64, using Castlabs Electron 45.2.1
and Widevine 4.10.3112.0.

The installed runtime and AppImage also pass automated H.264, AAC, VP9 and
Widevine capability checks with Chromium sandboxing enabled. This is local
validation, not a claim of compatibility with every Linux distribution.
Seeking, subtitles, fullscreen playback, session persistence across restarts,
and other distributions still need separate end-to-end testing. The diagnostic
report covers automated capabilities only; its playback-verification field
does not record manual user tests.

Run the account-free check:

```sh
npm run check:playback
```

It uses a local page in a temporary browser session. Exit codes: 0 = prerequisites
available, 1 = missing capability, 2 = initialization failure. A raw packaged
binary can return 3 when a first-run restart is required; run it again.
The source and installed launchers handle that restart automatically.

A sanitized report is saved as `playback-diagnostics.json` under the Electron
profile, normally `~/.config/nflix-desktop`. It contains runtime versions and
capability results, not cookies, license challenges or browsing history.

## Desktop behavior

- Persistent Netflix session and window geometry.
- Fullscreen: F11; exit with Escape.
- Compact always-on-top window: Ctrl+Shift+P.
- Press Alt to reveal the menu, including playback diagnostics.
- HTTPS Netflix pages stay in the app. Other HTTP(S) links require confirmation
  before opening in the system browser.
- Remote pages have no Node.js access or preload bridge. Context isolation and
  Chromium sandboxing remain enabled.
- Arbitrary downloads and unrelated web permissions are denied.

The old Qt profile is left intact; log in again after migration. Do not copy
cookies or browser databases between engines.

## Build and install locally

```sh
npm run pack
./install.sh
```

The installer copies `release/linux-unpacked` to
`~/.local/lib/nflix-desktop/electron` and refreshes the applications-menu entry.
Reinstalling replaces the Electron runtime; the previous copy is retained as
`electron.previous`. Existing Python files and user profiles are preserved.

Launch **Nflix Desktop** from the applications menu, or run:

```sh
~/.local/bin/nflix-desktop
~/.local/bin/nflix-desktop --check-playback
```

`./uninstall.sh` removes the installed application while retaining user profiles.

## Distribution builds

```sh
scripts/build-release.sh
```

Builds AppImage, tar.gz, DEB and RPM files with checksums in `release/`.
DEB/RPM tooling requires `rpmbuild` and the `libcrypt.so.1` compatibility
library on the build host (Fedora: `rpm-build` and `libxcrypt-compat`).
These are build dependencies, not application dependencies.
The tar archive contains a runnable application directory. Electron Builder
copies the installed **Castlabs** runtime rather than downloading stock
Electron. Building may download packaging tools; Node.js is not needed to run
the packaged app.

The initial target is glibc-based Linux x86_64. Ubuntu/Debian, Fedora and Arch,
GNOME/KDE, X11/Wayland, and GPU driver combinations require runtime testing.
The host must support Chromium sandboxing; Nflix refuses sandbox-disabling launch flags.
ARM64, musl-based distributions, Flatpak and Snap are not validated targets.
Do not advertise universal Linux compatibility.

Tag builds validate the version and publish a prerelease. They do not establish
playback compatibility. Test a protected Netflix title in each final package
before promoting a release.

## Development

`npm test` checks navigation trust, web permissions and persisted window state.
`NFLIX_USER_DATA=/absolute/test/profile npm start -- --smoke-test` performs an
isolated visible launch, checks renderer security settings, saves a screenshot,
and exits. Use a disposable profile, not an account-bearing profile.

The previous Python/Qt implementation, including unfinished codec work and old
packaging recipes, is preserved under `legacy/qt`. It is excluded from the
Electron application and is no longer the active build path.

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and
[third-party notices](THIRD_PARTY_NOTICES.md).
