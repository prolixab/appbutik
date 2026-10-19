#!/usr/bin/env bash
# Gathers every APK for this build into fdroid/repo:
#   1. APKs committed to apks/
#   2. The latest GitHub release asset of each repo listed in sources.txt
set -euo pipefail
cd "$(dirname "$0")/.."

dest=fdroid/repo
mkdir -p "$dest"
shopt -s nullglob

for apk in apks/*.apk; do
  cp "$apk" "$dest/"
  echo "local: $apk"
done

tmp=$(mktemp -d)
{ grep -vE '^[[:space:]]*(#|$)' sources.txt || true; } | while read -r repo pattern _; do
  dir="$tmp/${repo//\//_}"
  mkdir -p "$dir"
  if ! gh release download --repo "$repo" --pattern "${pattern:-*.apk}" --dir "$dir"; then
    echo "::warning::Could not download a release APK from $repo"
    continue
  fi
  # Gradle names every APK app-release.apk, so prefix with the repo name to avoid collisions.
  for apk in "$dir"/*.apk; do
    cp "$apk" "$dest/${repo##*/}-$(basename "$apk")"
    echo "release: $repo -> ${repo##*/}-$(basename "$apk")"
  done
done

echo "$(ls "$dest"/*.apk 2>/dev/null | wc -l) APK(s) collected"
