# Appbutik

A private app store for your own Android apps. It is an [F-Droid](https://f-droid.org) repository built by GitHub Actions and hosted on Coolify at `https://appstore.prolixab.se`. Phones add it once in the F-Droid client and then get your apps and their updates from it.

```
apks/*.apk  ─┐                                                     ┌─► nginx image (ghcr.io) ─► Coolify
sources.txt ─┴─► collect-apks.sh ─► fdroid update (signs index) ───┤
                                                                   └─► GitHub Pages (old URL, during the move)
site:  /          landing page + QR
       /repo      F-Droid repo
```

## Hosting on Coolify

Each build pushes `ghcr.io/prolixab/appbutik:latest` and then calls Coolify's deploy webhook.

- Coolify resource: **Docker Image** `ghcr.io/prolixab/appbutik:latest`, port 80, domain `https://appstore.prolixab.se`. The package must be public on GitHub, or Coolify needs registry credentials.
- Actions secrets: `COOLIFY_WEBHOOK` (the resource's deploy webhook URL) and `COOLIFY_TOKEN` (an API token with deploy rights). Without them the image is pushed but not deployed.
- Actions variable: `REPO_URL = https://appstore.prolixab.se/repo`.

GitHub Pages still serves the same build at `https://prolixab.github.io/appbutik/` so phones that added the old URL keep getting updates. Once every phone has re-added the store from the new address, remove the Pages steps and the `deploy` job from the workflow.

## One-time setup

1. **Signing key** (already done once; never regenerate it):
   `npm install && npm run keystore` → writes `../appbutik-secrets/`.
   **Back that folder up** (password manager or USB stick). If you lose the key, every phone has to remove the store and add it again.
2. **GitHub:** `gh auth login`, then `bash scripts/setup-github.sh OWNER/appbutik`.
   This creates a public repo, stores the key as Actions secrets, turns on Pages and pushes.
3. Open `https://appstore.prolixab.se/` on the phone and tap **Lägg till i F-Droid**.

## Publishing an app

You can either:

- **Drop the APK** into `apks/` and push. Use a unique file name per app.
- **Add its GitHub repo** to `sources.txt`. Every build pulls the APK from that repo's latest release. Rebuilds happen daily, or on demand from the app repo's release workflow:
  ```bash
  gh api repos/OWNER/appbutik/dispatches -f event_type=app-released
  ```
  Private app repos need a `SOURCES_TOKEN` secret (fine-grained PAT, Contents: read).

## Releasing an app from its repository

Apps don't need their own build-and-sign pipeline. `.github/workflows/android-app-release.yml` is a shared release workflow: it checks the version, builds, signs with the app's key, verifies the certificate, publishes a GitHub Release with the APK and `SHA256SUMS.txt`, and notifies this store. Each app repository calls it from a short workflow of its own, for example:

```yaml
name: Android release
on:
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      publish:
        description: Publish a release (tag v<version> on the default branch)
        type: boolean
        default: false
permissions:
  contents: write
jobs:
  release:
    uses: prolixab/appbutik/.github/workflows/android-app-release.yml@main
    with:
      app-name: chessy
      version-command: node -p "require('./package.json').version"
      build-command: npm run android:sync && cd android && chmod +x gradlew && ./gradlew assembleRelease --no-daemon
      apk-path: android/app/build/outputs/apk/release/app-release-unsigned.apk
      java-version: '21'
      publish: ${{ inputs.publish == true }}
    secrets: inherit
```

Other inputs: `install-command` (default `npm ci`), `check-command` (tests, run before the build), `node-version` (22), `timeout-minutes` (90). The build sees `RELEASE_VERSION` and `VERSION_CODE` (the run number, always increasing) in its environment.

**Adding an app:**

1. Store its signing key in the app repo: `bash scripts/setup-app.sh OWNER/APP signing.properties` (or a `.jks` file, which prompts for the alias and passwords). Use the key the app has always been signed with.
2. Add the caller workflow above to the app repo.
3. Add `OWNER/APP` to `sources.txt`. For a private repo, also give `SOURCES_TOKEN` access to it.

**Releasing:** bump the version, merge, then run **Actions → Android release** on the default branch with **publish** ticked. It refuses to publish a version that is already tagged. Pushing a `v<version>` tag works too; the tag must match the app version.

## Rules for the APKs

- They must be **release-signed**. Debug APKs work but are fragile.
- **Bump `versionCode`** for every update. F-Droid only offers a newer versionCode.
- **Always sign each app with the same key.** Android refuses updates signed with a different key. This app key is separate from the store key in `appbutik-secrets`.
- Store listings are optional. See `fdroid/metadata/se.example.myapp.yml.sample`.

## Optional settings (repo → Settings → Variables)

| Variable | Default |
|---|---|
| `REPO_NAME` | `Appbutik` |
| `REPO_URL` | `https://OWNER.github.io/REPO/repo` (set it if you use a custom domain; it must end in `/repo`) |

Changing `REPO_URL` after phones have added the store means re-adding it on each phone.
