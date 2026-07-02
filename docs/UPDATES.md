# Auto-updates (Sparkle)

OpenCrashCart updates itself with [Sparkle](https://sparkle-project.org). Users get a
**Check for Updates…** item in the app menu and automatic background checks; a **Settings →
Updates → Receive dev (beta) builds** toggle opts into the pre-release channel.

## How the channels map

There is a **single appcast feed** (`SUFeedURL` in `packaging/Info.plist`). Stable and dev
builds both live in it; dev builds are tagged `<sparkle:channel>dev</sparkle:channel>` and are
only offered to users who enabled the dev toggle. This mirrors the repo's `main` (stable) /
`dev` (pre-release) split:

| Build         | Release script flag | Who receives it                         |
|---------------|---------------------|-----------------------------------------|
| stable        | *(none)*            | everyone                                |
| dev / beta    | `--dev`             | only users with "Receive dev builds" on |

## Signing keys

Sparkle updates are signed with an **EdDSA key pair** (separate from Apple code signing):

- The **public key** is baked into `packaging/Info.plist` as `SUPublicEDKey`.
- The **private key** lives in the release machine's **login Keychain** (created by Sparkle's
  `generate_keys`). It is never committed and never leaves that Mac.

**Back it up** — losing it means you can't ship verifiable updates to existing installs. Export
a backup file with:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private_key.txt   # store securely, then delete
```

To regenerate from scratch (new key) you must also update `SUPublicEDKey` in Info.plist, which
breaks updates for anyone on an older build — avoid unless the key is lost.

## Cutting a release

1. **Build the signed app bundle.** For a real (notarizable) release pass a Developer ID;
   omit `OCC_SIGN_ID` for a local ad-hoc build.

   ```sh
   OCC_SIGN_ID="Developer ID Application: Your Name (TEAMID)" scripts/make-app.sh
   ```

2. **Zip it** (Sparkle installs from a zip of the `.app`):

   ```sh
   ditto -c -k --keepParent dist/OpenCrashCart.app dist/OpenCrashCart-<version>.zip
   ```

3. **Sign + generate the appcast.** Add `--dev` for a pre-release. This reads the private key
   from your Keychain (approve the prompt the first time), signs the zip, and writes
   `dist/updates/appcast.xml`:

   ```sh
   scripts/release-appcast.sh dist/OpenCrashCart-<version>.zip          # stable
   scripts/release-appcast.sh dist/OpenCrashCart-<version>.zip --dev    # dev channel
   ```

4. **Publish to GitHub Pages.** The feed is served from the `gh-pages` branch; this script
   overlays `dist/updates/` (appcast + zips) onto it and pushes:

   ```sh
   scripts/publish-pages.sh
   ```

   It preserves the existing landing page and past releases (additive only). Within a minute or
   so the update is live at the `SUFeedURL`.

The `dist/updates/` directory is your local mirror of the feed: keep past versions in it so
`generate_appcast` can preserve their entries (and build delta updates) on each run.

## Hosting layout

GitHub Pages serves the **`gh-pages`** branch (root) at
`https://adamson34.github.io/open-crash-cart/`. That branch holds `appcast.xml`, the release
`.zip`s, a `.nojekyll` marker (so files are served verbatim), and an `index.html` landing page.
`scripts/publish-pages.sh` is the only thing that should write to it.

## Notarization (recommended, separate concern)

Auto-update works without Apple notarization — Sparkle verifies its own EdDSA signature and
installs the update itself. But a **notarized** Developer ID build removes the Gatekeeper
warning on first launch. Notarize the zip after step 2:

```sh
xcrun notarytool submit dist/OpenCrashCart-<version>.zip --keychain-profile <profile> --wait
xcrun stapler staple dist/OpenCrashCart.app     # then re-zip for distribution
```

## Local development

Under `swift run` / the bare `.build/debug/occ` binary there is no app bundle, feed, or
signature, so Sparkle can't run — `UpdaterManager.isAvailable` is false and **Check for
Updates…** stays disabled. Build the `.app` (`scripts/make-app.sh`) to exercise updates.
