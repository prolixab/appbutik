# Appbutik

A private app store for your own Android apps. It is an [F-Droid](https://f-droid.org) repository built by GitHub Actions and hosted on GitHub Pages. Phones add it once in the F-Droid client and then get your apps and their updates from it.

```
apks/*.apk  ─┐
sources.txt ─┴─► collect-apks.sh ─► fdroid update (signs index) ─► GitHub Pages
                                                                   ├─ /          landing page + QR
                                                                   └─ /repo      F-Droid repo
```

## One-time setup

1. **Signing key** (already done once; never regenerate it):
   `npm install && npm run keystore` → writes `../appbutik-secrets/`.
   **Back that folder up** (password manager or USB stick). If you lose the key, every phone has to remove the store and add it again.
2. **GitHub:** `gh auth login`, then `bash scripts/setup-github.sh OWNER/appbutik`.
   This creates a public repo, stores the key as Actions secrets, turns on Pages and pushes.
3. Open `https://OWNER.github.io/appbutik/` on the phone and tap **Lägg till i F-Droid**.

## Publishing an app

You can either:

- **Drop the APK** into `apks/` and push. Use a unique file name per app.
- **Add its GitHub repo** to `sources.txt`. Every build pulls the APK from that repo's latest release. Rebuilds happen daily, or on demand from the app repo's release workflow:
  ```bash
  gh api repos/OWNER/appbutik/dispatches -f event_type=app-released
  ```
  Private app repos need a `SOURCES_TOKEN` secret (fine-grained PAT, Contents: read).

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
