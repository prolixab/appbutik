#!/usr/bin/env bash
# Builds and signs the F-Droid index, then assembles the Pages site in site/.
# Needs: fdroidserver, a JDK, and these env vars:
#   REPO_URL (ending in /repo), REPO_NAME, FDROID_KEYSTORE_B64, FDROID_KEYSTORE_PASS, FDROID_KEY_ALIAS
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD

: "${REPO_URL:?}" "${REPO_NAME:?}" "${FDROID_KEYSTORE_B64:?}" "${FDROID_KEYSTORE_PASS:?}" "${FDROID_KEY_ALIAS:?}"

cd fdroid
umask 077
echo "$FDROID_KEYSTORE_B64" | base64 -d > keystore.p12
trap 'rm -f "$root/fdroid/keystore.p12" "$root/fdroid/config.yml"' EXIT

cat > config.yml <<EOF
repo_url: $REPO_URL
repo_name: $REPO_NAME
repo_description: >-
  Egna Android-appar, publicerade direkt härifrån.
repo_icon: icon.png
archive_older: 0
repo_keyalias: $FDROID_KEY_ALIAS
keystore: keystore.p12
keystorepass: $FDROID_KEYSTORE_PASS
keypass: $FDROID_KEYSTORE_PASS
keydname: CN=Appbutik, O=Appbutik
sdk_path: ${ANDROID_HOME:-/usr/lib/android-sdk}
EOF
umask 022

mkdir -p repo/icons
cp "$root/branding/icon.png" repo/icons/icon.png

fdroid update --create-metadata --pretty

fingerprint=$(keytool -exportcert -alias "$FDROID_KEY_ALIAS" -keystore keystore.p12 \
  -storepass "$FDROID_KEYSTORE_PASS" | sha256sum | cut -d' ' -f1)
echo "Repo fingerprint: $fingerprint"

cd "$root"
rm -rf site
mkdir -p site
cp -r fdroid/repo site/repo
rm -f site/repo/index.html  # our own landing page lives one level up
cp branding/icon.png site/icon.png
sed -e "s|__REPO_URL__|$REPO_URL|g" \
    -e "s|__REPO_NAME__|$REPO_NAME|g" \
    -e "s|__FINGERPRINT__|$fingerprint|g" \
    branding/index.html > site/index.html
touch site/.nojekyll
