#!/bin/sh
# Create or rotate the cluster-only Tailscale OAuth Secret without placing either
# value in Git, shell arguments, terminal output, or a persistent plaintext file.
set -eu
umask 077

if [ "$#" -ne 0 ]; then
  printf '%s\n' "usage: RUDTAL_KUBECONFIG=state/kubeconfig $0" >&2
  exit 64
fi

: "${RUDTAL_KUBECONFIG:?set RUDTAL_KUBECONFIG to the explicit administrator kubeconfig path}"
if [ ! -f "$RUDTAL_KUBECONFIG" ]; then
  printf '%s\n' "RUDTAL_KUBECONFIG is not a readable file" >&2
  exit 66
fi

cleanup() {
  stty echo 2>/dev/null || true
  rm -rf "$tmpdir"
}
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/rudtal-tailscale-oauth.XXXXXX")
trap cleanup 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

printf '%s' 'Tailscale OAuth client ID: ' >&2
IFS= read -r client_id
printf '%s' 'Tailscale OAuth client secret (hidden): ' >&2
stty -echo
auth_read=0
IFS= read -r client_secret && auth_read=1
stty echo
printf '\n' >&2
if [ "$auth_read" -ne 1 ] || [ -z "$client_id" ] || [ -z "$client_secret" ]; then
  printf '%s\n' "Both OAuth values are required; no Secret was changed." >&2
  exit 65
fi

printf %s "$client_id" >"$tmpdir/client_id"
printf %s "$client_secret" >"$tmpdir/client_secret"

kubectl --kubeconfig "$RUDTAL_KUBECONFIG" create namespace tailscale \
  --dry-run=client -o yaml | kubectl --kubeconfig "$RUDTAL_KUBECONFIG" apply -f -
kubectl --kubeconfig "$RUDTAL_KUBECONFIG" --namespace tailscale create secret generic operator-oauth \
  --from-file=client_id="$tmpdir/client_id" \
  --from-file=client_secret="$tmpdir/client_secret" \
  --dry-run=client -o yaml >"$tmpdir/operator-oauth.yaml"
kubectl --kubeconfig "$RUDTAL_KUBECONFIG" apply -f "$tmpdir/operator-oauth.yaml"
printf '%s\n' "tailscale/operator-oauth created or updated; credential values were not displayed."
