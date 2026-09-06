#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT_DIR/versions.env"

TALOSCTL="$ROOT_DIR/downloads/talosctl-v1.12.12-darwin-arm64"
SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE:-"$HOME/.config/sops/age/rudtal.txt"}
export SOPS_AGE_KEY_FILE

usage() {
  printf '%s\n' "usage: $0 generated/<node>/<controlplane|worker>.yaml" "       $0 secrets" >&2
  exit 2
}

[ "$#" -eq 1 ] || usage

if [ "$1" = secrets ]; then
  [ -r "$SOPS_AGE_KEY_FILE" ] || {
    printf '%s\n' "missing SOPS age identity: $SOPS_AGE_KEY_FILE" >&2
    exit 1
  }
  mkdir -p "$ROOT_DIR/generated"
  work_dir=$(mktemp -d "$ROOT_DIR/generated/validate.XXXXXX")
  trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
  sops --decrypt --output "$work_dir/secrets.yaml" "$ROOT_DIR/talos/secrets.sops.yaml"
  chmod 600 "$work_dir/secrets.yaml"
  printf '%s\n' 'encrypted Talos secrets decrypt successfully'
  exit 0
fi

config=$1
[ -f "$config" ] || {
  printf '%s\n' "missing machine config: $config" >&2
  exit 1
}
[ -x "$TALOSCTL" ] || {
  printf '%s\n' "missing pinned talosctl: $TALOSCTL" >&2
  exit 1
}

"$TALOSCTL" validate --mode metal --strict --config "$config"
