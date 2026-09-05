#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT_DIR/versions.env"

TALOSCTL="$ROOT_DIR/downloads/talosctl-v1.12.12-darwin-arm64"
SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE:-"$HOME/.config/sops/age/rudtal.txt"}
export SOPS_AGE_KEY_FILE
EXTRA_CONFIG_PATCH=${EXTRA_CONFIG_PATCH:-}
if [ -n "$EXTRA_CONFIG_PATCH" ]; then
  case "$EXTRA_CONFIG_PATCH" in
    /*) ;;
    *) EXTRA_CONFIG_PATCH="$ROOT_DIR/$EXTRA_CONFIG_PATCH" ;;
  esac
fi

usage() {
  printf '%s\n' "usage: $0 controlplane rudtal-cp-1" "       $0 worker rudtal-worker-1|rudtal-worker-2" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
role=$1
node=$2

case "$role:$node" in
  controlplane:rudtal-cp-1)
    role_patch="$ROOT_DIR/talos/patches/controlplane.yaml"
    output_types=controlplane,talosconfig
    output_name=controlplane.yaml
    install_disk=$CONTROL_PLANE_INSTALL_DISK
    role_flag=--config-patch-control-plane
    ;;
  worker:rudtal-worker-1|worker:rudtal-worker-2)
    role_patch="$ROOT_DIR/talos/patches/worker.yaml"
    output_types=worker
    output_name=worker.yaml
    : "${INSTALL_DISK:?Set INSTALL_DISK to the disk confirmed for this worker}"
    install_disk=$INSTALL_DISK
    role_flag=--config-patch-worker
    ;;
  *)
    usage
    ;;
esac

[ -x "$TALOSCTL" ] || {
  printf '%s\n' "missing pinned talosctl: $TALOSCTL" >&2
  exit 1
}
[ -r "$SOPS_AGE_KEY_FILE" ] || {
  printf '%s\n' "missing SOPS age identity: $SOPS_AGE_KEY_FILE" >&2
  exit 1
}

for path in \
  "$ROOT_DIR/talos/secrets.sops.yaml" \
  "$ROOT_DIR/talos/patches/common.yaml" \
  "$role_patch" \
  "$ROOT_DIR/talos/patches/nodes/$node.yaml"
do
  [ -r "$path" ] || {
    printf '%s\n' "missing input: $path" >&2
    exit 1
  }
done
if [ -n "$EXTRA_CONFIG_PATCH" ]; then
  [ -r "$EXTRA_CONFIG_PATCH" ] || {
    printf '%s\n' "missing extra config patch: $EXTRA_CONFIG_PATCH" >&2
    exit 1
  }
fi

mkdir -p "$ROOT_DIR/generated"
work_dir=$(mktemp -d "$ROOT_DIR/generated/render.XXXXXX")
output_dir="$ROOT_DIR/generated/$node"
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

sops --decrypt "$ROOT_DIR/talos/secrets.sops.yaml" > "$work_dir/secrets.yaml"
rm -rf "$output_dir"
mkdir -p "$output_dir"

if [ "$role" = controlplane ]; then
  output_target=$output_dir
else
  output_target=$output_dir/$output_name
fi

render_config() {
  "$TALOSCTL" gen config "$CLUSTER_NAME" "$CLUSTER_ENDPOINT" \
    --with-secrets "$work_dir/secrets.yaml" \
    --talos-version "$TALOS_VERSION" \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --install-disk "$install_disk" \
    --config-patch "@$ROOT_DIR/talos/patches/common.yaml" \
    "$role_flag" "@$role_patch" \
    --config-patch "@$ROOT_DIR/talos/patches/nodes/$node.yaml" \
    "$@" \
    --output-types "$output_types" \
    --output "$output_target" \
    --with-docs=false \
    --with-examples=false \
    --force
}

if [ -n "$EXTRA_CONFIG_PATCH" ]; then
  render_config --config-patch "@$EXTRA_CONFIG_PATCH"
else
  render_config
fi

chmod 600 "$output_dir/$output_name"
if [ "$role" = controlplane ]; then
  chmod 600 "$output_dir/talosconfig"
  talos_endpoint=${CLUSTER_ENDPOINT#https://}
  talos_endpoint=${talos_endpoint%%:*}
  "$TALOSCTL" --talosconfig "$output_dir/talosconfig" config endpoint "$talos_endpoint"
  "$TALOSCTL" --talosconfig "$output_dir/talosconfig" config node "$talos_endpoint"
fi
printf '%s\n' "rendered $output_dir/$output_name"
if [ "$role" = controlplane ]; then
  printf '%s\n' "rendered $output_dir/talosconfig"
fi
