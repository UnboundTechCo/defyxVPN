#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"
cd "$project_root"

pub_cache="${PUB_CACHE:-$HOME/.pub-cache}"

for plugin in firebase_analytics firebase_core; do
    version=$(awk -v package="$plugin" '
        $0 == "  " package ":" { reading = 1; next }
        reading && /^    version: / { gsub(/[" ]/, "", $2); print $2; exit }
        reading && /^  [^ ]/ { exit }
    ' pubspec.lock)
    gradle_file="${pub_cache}/hosted/pub.dev/${plugin}-${version}/android/build.gradle"
    if [[ -z "$version" || ! -f "$gradle_file" ]]; then
        printf 'Could not find cached Gradle script for %s\n' "$plugin" >&2
        exit 1
    fi

    count=$(grep -Ec "^[[:space:]]*apply plugin: 'kotlin-android'[[:space:]]*$" "$gradle_file" || true)
    if [[ "$count" == "1" ]]; then
        perl -0pi -e 's{^([ \t]*)apply plugin: \x27kotlin-android\x27}{$1pluginManager.apply(\x27kotlin-android\x27)}m' "$gradle_file"
    elif [[ "$count" != "0" ]] || ! grep -Fq "pluginManager.apply('kotlin-android')" "$gradle_file"; then
        printf 'Unexpected Kotlin plugin declaration in %s\n' "$gradle_file" >&2
        exit 1
    fi
done