#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils curl gnugrep gnused gnutar gzip jq nix nix-update nodejs_24

if [[ -z "${OC_DESKTOP_UPDATE_SHELL:-}" ]] && ! command -v jq >/dev/null 2>&1; then
  export OC_DESKTOP_UPDATE_SHELL=1
  exec nix-shell -p bash coreutils curl gnugrep gnused gnutar gzip jq nix nix-update nodejs_24 \
    --run "bash $(readlink -f "${BASH_SOURCE[0]}")"
fi

set -euo pipefail

if [[ -f "$PWD/flake.nix" && -d "$PWD/pkgs/openchamber-desktop" ]]; then
  REPO_ROOT="$PWD"
else
  SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

if [[ ! -f "$REPO_ROOT/flake.nix" ]]; then
  echo "ERROR: could not determine the repository root; run from the repo via nix-update or ./pkgs/openchamber-desktop/update.sh" >&2
  exit 1
fi

PKG_FILE="$REPO_ROOT/pkgs/openchamber-desktop/default.nix"
LOCK_FILE="$REPO_ROOT/pkgs/openchamber-desktop/package-lock.json"

latest_tag="$(
  curl -fsSL https://api.github.com/repos/openchamber/openchamber/releases/latest |
    jq -r '.tag_name'
)"
latest="${latest_tag#v}"

current="$(
  sed -nE 's/^  version = "([^"]+)";/\1/p' "$PKG_FILE" | head -n 1
)"

if [[ "$latest" == "$current" ]]; then
  echo "openchamber-desktop is already up to date ($latest)"
  exit 0
fi
echo "Updating openchamber-desktop $current -> $latest"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

curl -fsSL \
  "https://github.com/openchamber/openchamber/archive/refs/tags/${latest_tag}.tar.gz" \
  -o "$tmp_dir/src.tar.gz"
tar -xzf "$tmp_dir/src.tar.gz" -C "$tmp_dir"
src_root="$tmp_dir/openchamber-$latest"

sed -i '/"packageManager":/d' "$src_root/package.json"
sed -i '/"overrides"/,/^  }/d' "$src_root/package.json"
sed -i -E 's/"workspace:[^"]*"/"*"/g' \
  "$src_root/package.json" \
  "$src_root"/packages/*/package.json

(
  cd "$src_root"
  npm install --package-lock-only --ignore-scripts --no-audit --no-fund
  for _ in 1 2 3; do
    cp package-lock.json package-lock.before.json
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null
    if cmp -s package-lock.before.json package-lock.json; then
      rm -f package-lock.before.json
      break
    fi
  done
  rm -f package-lock.before.json
)
cp "$src_root/package-lock.json" "$LOCK_FILE"

(
  cd "$REPO_ROOT"
  nix-update --flake --version "$latest" openchamber-desktop
)

echo "Updated openchamber-desktop to $latest"