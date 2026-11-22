# Contributing

Thanks for helping improve Nflix Desktop. Keep changes focused, explain user-visible behavior in pull requests, and avoid including Netflix artwork, screenshots containing copyrighted media, credentials, or personal data. The project icon is `assets/icon-512.png`; the Qt resource source is `assets/resources.qrc`.

## Local workflow

1. Use Python 3.10 or newer on Linux.
2. Create `.venv`, install the project with `.venv/bin/python -m pip install .`, then run `./run.sh`.
3. Regenerate the embedded icon after changing it: `.venv/bin/pyside6-rcc assets/resources.qrc -o app_resources.py`.
4. Build a standalone package with `scripts/build-release.sh`; test it on the target Linux distribution before release.
5. Keep navigation restricted to HTTPS Netflix pages. Avoid granting web permissions without a documented need.

Please report playback problems with the OS, GPU/driver, Qt version, and relevant sanitized logs. Never attach cookies, account details, or license challenge data. Keep the AppStream version, `pyproject.toml`, and release tag synchronized.
