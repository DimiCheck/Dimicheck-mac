# DimiCheck Mac

Minimal macOS menu bar companion app for DimiCheck.

## Features

- OAuth PKCE login with the server-seeded public client `dimicheck-mac-public`
- Refresh token persistence in Keychain
- Menu bar status icon and quick status changes
- Favorite status selection and right-click quick toggle
- Today view for timetable and meal
- Login-at-startup toggle
- Server-driven update policy for Homebrew and direct-download users

## Install

Recommended:

```bash
brew install --cask DimiCheck/dimicheck/dimicheck-mac
```

Direct download users can install the `DimiCheck-Mac-<version>.dmg` from GitHub Releases.

This app is currently ad-hoc signed because it is distributed without an Apple Developer ID certificate. macOS may show an unidentified-developer warning for direct downloads.

## Configure

The app defaults to:

- Base URL: `https://dimicheck.com`
- OAuth client ID: `dimicheck-mac-public`
- Redirect URIs: `http://127.0.0.1:45823/oauth-callback` through `http://127.0.0.1:45827/oauth-callback`, fallback `dimicheckmac://oauth-callback`
- Scopes: `basic student_info status.read status.write`

Environment variables supported at launch/build time:

- `DIMICHECK_SERVER_BASE_URL`
- `DIMICHECK_OAUTH_CLIENT_ID`
- `DIMICHECK_OAUTH_REDIRECT_URI`
- `DIMICHECK_OAUTH_REDIRECT_URIS`
- `DIMICHECK_OAUTH_SCOPES`

## Build

```bash
swift build
swift test
./scripts/build-app.sh
```

## Package

```bash
./scripts/package-release.sh
```

The packaging script creates:

- `dist/DimiCheck-Mac-<version>.zip`
- `dist/DimiCheck-Mac-<version>.dmg`
- `dist/SHA256SUMS`

## Release Checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Run `swift test`.
3. Run `./scripts/package-release.sh`.
4. Create a GitHub Release tagged `v<version>` and upload the zip, dmg, and `SHA256SUMS`.
5. Update the Homebrew cask sha256 with the dmg checksum.
6. Set the DimiCheck server version policy:
   - `MAC_APP_LATEST_VERSION=<version>`
   - `MAC_APP_MIN_SUPPORTED_VERSION=<minimum allowed version>`
   - `MAC_APP_DOWNLOAD_URL=https://dimicheck.com/mac.html`
   - `MAC_APP_HOMEBREW_COMMAND=brew upgrade --cask DimiCheck/dimicheck/dimicheck-mac`
   - `MAC_APP_UPDATE_MESSAGE=<short update message>`
