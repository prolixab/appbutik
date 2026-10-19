#!/usr/bin/env bash
# One-time: creates the GitHub repo, stores the signing key as secrets, enables Pages and pushes.
# Usage: bash scripts/setup-github.sh OWNER/REPO [path-to-secrets-dir]
set -euo pipefail
cd "$(dirname "$0")/.."

repo=${1:?usage: setup-github.sh OWNER/REPO [secrets-dir]}
secrets=${2:-../appbutik-secrets}

[ -f "$secrets/keystore.b64" ] || { echo "No keystore in $secrets — run: npm run keystore"; exit 1; }

if [ ! -d .git ]; then
  git init -q -b main
  git add -A
  git commit -q -m "Initial store"
fi

# Free GitHub Pages needs a public repo; the APKs and the index are public anyway.
gh repo view "$repo" >/dev/null 2>&1 || gh repo create "$repo" --public --source . --remote origin
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$repo.git"

gh secret set FDROID_KEYSTORE_B64 --repo "$repo" < "$secrets/keystore.b64"
gh secret set FDROID_KEYSTORE_PASS --repo "$repo" --body "$(grep '^FDROID_KEYSTORE_PASS=' "$secrets/secrets.env" | cut -d= -f2-)"
gh secret set FDROID_KEY_ALIAS --repo "$repo" --body "$(grep '^FDROID_KEY_ALIAS=' "$secrets/secrets.env" | cut -d= -f2-)"

gh api -X POST "repos/$repo/pages" -f build_type=workflow >/dev/null 2>&1 \
  || gh api -X PUT "repos/$repo/pages" -f build_type=workflow >/dev/null

git push -u origin main
echo "Done. Watch the build: gh run watch --repo $repo"
