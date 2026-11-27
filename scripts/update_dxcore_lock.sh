#!/usr/bin/env bash
# Pins the app to a DXcore release: downloads its assets, and writes the tag
# and their SHA-256 to .github/dxcore.lock. If the release publishes
# SHA256SUMS, every hash must match it.
#
# The four assets in `assets` must be there. DXcore-macos.zip is pinned when
# the release has it; without it the lock is still written, and only the
# macOS build has no core to fetch.
#
# Usage: GITHUB_TOKEN=<token with read access to DXcore-private> \
#          scripts/update_dxcore_lock.sh r6.1.4
set -euo pipefail

tag=${1:?usage: GITHUB_TOKEN=... $0 <dxcore tag>}
: "${GITHUB_TOKEN:?set GITHUB_TOKEN to a token that can read DXcore-private}"

root=$(cd "$(dirname "$0")/.." && pwd)
lock="$root/.github/dxcore.lock"
api=https://api.github.com/repos/UnboundTechCo/DXcore-private
assets=(DXcore-android.zip DXcore-ios.zip DXcore-linux.zip DXcore-windows.zip)
optional_assets=(DXcore-macos.zip)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

fetch() {
  local name=$1 id
  id=$(jq -r --arg name "$name" '.assets[] | select(.name == $name) | .id' "$work/release.json")
  if [ -z "$id" ] || [ "$id" = null ]; then
    return 1
  fi
  curl -fsSL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/octet-stream" \
    "$api/releases/assets/$id" -o "$work/$name"
}

curl -fsSL -H "Authorization: token $GITHUB_TOKEN" "$api/releases/tags/$tag" -o "$work/release.json"

published=""
if fetch SHA256SUMS; then
  published="$work/SHA256SUMS"
else
  echo "warning: DXcore $tag publishes no SHA256SUMS, hashes are only taken from the download" >&2
fi

# Adds a downloaded asset's hash to the lock, after checking it against
# SHA256SUMS when the release publishes one.
pin() {
  local name=$1 sum want
  sum=$(sha256 "$work/$name")
  if [ -n "$published" ]; then
    want=$(awk -v n="$name" '$2 == n || $2 == "*"n {print $1}' "$published")
    if [ "$want" != "$sum" ]; then
      echo "error: $name hashes to $sum, SHA256SUMS of $tag says '${want:-nothing}'" >&2
      exit 1
    fi
  fi
  lines+=("$name=$sum")
  echo "$name $sum"
}

lines=("tag=$tag")
for name in "${assets[@]}"; do
  fetch "$name" || { echo "error: DXcore $tag has no asset $name" >&2; exit 1; }
  pin "$name"
done
for name in "${optional_assets[@]}"; do
  if fetch "$name"; then
    pin "$name"
  else
    echo "warning: DXcore $tag has no asset $name, so the macOS build has no core to fetch" >&2
  fi
done

{
  echo "# The DXcore release every build uses, and the SHA-256 of each asset."
  echo "# CI refuses an asset whose hash differs. Change it with the Update DXcore"
  echo "# lock workflow or scripts/update_dxcore_lock.sh, never by hand."
  printf '%s\n' "${lines[@]}"
} > "$lock"
echo "Wrote $lock"
