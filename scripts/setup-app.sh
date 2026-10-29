#!/usr/bin/env bash
# One-time per app: stores the app's release signing key and the store token as Actions secrets in
# the app's repository, so its release workflow can sign APKs and notify this store.
# Usage:
#   bash scripts/setup-app.sh OWNER/APP-REPO path/to/signing.properties
#     (Gradle-style file with storeFile, storePassword, keyAlias, keyPassword)
#   bash scripts/setup-app.sh OWNER/APP-REPO path/to/release.jks
#     (prompts for the alias and passwords)
# Then add OWNER/APP-REPO to sources.txt. Nothing secret is printed or written to disk.
set -euo pipefail

repo=${1:?usage: setup-app.sh OWNER/APP-REPO signing.properties|release.jks}
source=${2:?usage: setup-app.sh OWNER/APP-REPO signing.properties|release.jks}

prop() { grep -E "^[[:space:]]*$1[[:space:]]*=" "$source" | head -n 1 | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

if [[ $source == *.properties ]]; then
  keystore=$(prop storeFile)
  # A relative storeFile is relative to the properties file.
  [[ $keystore == /* ]] || keystore="$(dirname "$source")/$keystore"
  store_pass=$(prop storePassword)
  alias=$(prop keyAlias)
  key_pass=$(prop keyPassword)
else
  keystore=$source
  read -r -p "Key alias: " alias
  read -r -s -p "Keystore password: " store_pass; echo
  read -r -s -p "Key password (Enter = same as keystore): " key_pass; echo
  key_pass=${key_pass:-$store_pass}
fi

[ -f "$keystore" ] || { echo "Keystore not found: $keystore"; exit 1; }
[ -n "$alias" ] && [ -n "$store_pass" ] && [ -n "$key_pass" ] || { echo "Missing alias or password"; exit 1; }
# Fail early on a wrong password or alias instead of in the release build.
STORE_PASS=$store_pass keytool -list -keystore "$keystore" -alias "$alias" -storepass:env STORE_PASS >/dev/null \
  || { echo "keytool could not open alias '$alias' with that password"; exit 1; }

base64 < "$keystore" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$repo"
gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$repo" --body "$store_pass"
gh secret set ANDROID_KEY_ALIAS --repo "$repo" --body "$alias"
gh secret set ANDROID_KEY_PASSWORD --repo "$repo" --body "$key_pass"

if ! gh secret list --repo "$repo" | grep -q '^APPBUTIK_TOKEN'; then
  echo "Optional: a token that may trigger this store's rebuild (fine-grained PAT on prolixab/appbutik, Contents: read and write)."
  read -r -s -p "APPBUTIK_TOKEN (Enter to skip; the store then updates daily): " token; echo
  [ -z "$token" ] || gh secret set APPBUTIK_TOKEN --repo "$repo" --body "$token"
fi

echo "Secrets stored in $repo. Next: add '$repo' to sources.txt, and if the repo is private, to SOURCES_TOKEN's repository access."
