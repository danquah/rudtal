# S07B Cilium physical rebuild runbook

This is a destructive, operator-present runbook for the disposable S07 rebuild.
It was prepared in S07A and was not executed there. Stop at any failed
checkpoint; do not improvise an in-place Flannel-to-Cilium migration.

## Fixed inputs and gates

Use only the reviewed S07 branch commit and these recorded values:

```sh
BRANCH=experiment/cilium-s07
BASELINE_COMMIT=850d7a23d0efcff74503820693f6ecd0de57ca94
CILIUM_CHART_DIGEST=sha256:876b611ff5c63b79d5e8e2621bdbad237ec9089cde72da333df61ff27b55fc81
CILIUM_VERSION=1.18.13
CONTROL_PLANE=192.168.1.121
WORKER_1=192.168.1.122
WORKER_2=192.168.1.123
```

Before touching a node, the operator and reviewer must approve all of the
following:

- the final S07 branch commit, the exact Talos patch, Cilium values and OCI
  digest;
- that every workload and all node-local storage are disposable;
- a one-time push/availability of the experiment branch for Flux bootstrap;
- erasing `/dev/nvme0n1` on each named node after the live disk match below;
- the rollback rebuild at `BASELINE_COMMIT` if Cilium acceptance fails.

No S07B action is authorized merely because S07A committed these files.

## Checkpoint 0: verify branch and baseline

This is local Git state only. It changes no cluster. The expected result is a
clean worktree on the reviewed experiment branch, with no Cilium commit on
`main` and no tag created for the baseline.

```sh
git fetch origin --prune
git switch experiment/cilium-s07
git status --short --branch
git rev-parse HEAD
git show --stat --oneline HEAD
git show --no-patch --format='%H %s' "$BASELINE_COMMIT"
```

If the branch is not already available to the Git server, stop here until the
operator approves the external Git change. Before Flux bootstrap, make the
reviewed commit reachable without merging it into `main`:

```sh
git push --set-upstream origin experiment/cilium-s07
```

Record the resulting remote branch commit. Do not push `main`, create a tag, or
use `--force`.

## Checkpoint 1: confirm the live Flannel baseline and disposable state

These are read-only Kubernetes checks. They inspect the current etcd state and
must show the known-good Flannel cluster before it is destroyed. Do not print
Secrets.

```sh
KUBECONFIG=state/kubeconfig kubectl get nodes -o wide
KUBECONFIG=state/kubeconfig kubectl get pods -n kube-system -o wide
KUBECONFIG=state/kubeconfig kubectl get pods -n flux-system -o wide
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" get sources git -A
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" get kustomizations -A
KUBECONFIG=state/kubeconfig kubectl get pvc -A
KUBECONFIG=state/kubeconfig kubectl get pods -A -l k8s-app=cilium --no-headers
```

Expected: three Ready nodes, Flannel/kube-proxy healthy, Flux Ready, no PVC or
Cilium pod that carries state needed for recovery. If any workload matters,
export it through its reviewed Git declaration or stop; never assume a local
emptyDir or node-local volume survives a rebuild.

## Checkpoint 2: render and validate, without displaying configs

The render layer is Talos configuration, not Kubernetes. It decrypts only into
ignored temporary storage and writes generated machine configs under ignored
`generated/`. Never `cat`, `diff`, commit or paste the resulting files.

```sh
EXTRA_CONFIG_PATCH=talos/patches/experiments/cilium-s07.yaml \
  ./scripts/render.sh controlplane rudtal-cp-1
EXTRA_CONFIG_PATCH=talos/patches/experiments/cilium-s07.yaml \
  INSTALL_DISK=/dev/nvme0n1 ./scripts/render.sh worker rudtal-worker-1
EXTRA_CONFIG_PATCH=talos/patches/experiments/cilium-s07.yaml \
  INSTALL_DISK=/dev/nvme0n1 ./scripts/render.sh worker rudtal-worker-2

./scripts/validate.sh generated/rudtal-cp-1/controlplane.yaml
./scripts/validate.sh generated/rudtal-worker-1/worker.yaml
./scripts/validate.sh generated/rudtal-worker-2/worker.yaml
```

Expected: all three strict metal validations pass. The generated control-plane
config must be treated as credential-bearing even though the patch itself is
public. If validation fails, correct the source patch or versioned input and
render again; do not apply a partially reviewed file.

## Checkpoint 3: match every physical node before reset

This is the destructive boundary. The goal is to prove that the endpoint, wired
MAC and internal disk match `INVENTORY.md` while each node is in maintenance
mode. The read-only `get` commands are safe to repeat. Applying a config and
wiping the install disk are not.

For each node, boot the pinned Talos v1.12.12 maintenance media through JetKVM
and run, without printing credential-bearing files:

```sh
TALOS=downloads/talosctl-v1.12.12-darwin-arm64
"$TALOS" --nodes 192.168.1.121 get links --insecure
"$TALOS" --nodes 192.168.1.121 get disks --insecure
"$TALOS" --nodes 192.168.1.122 get links --insecure
"$TALOS" --nodes 192.168.1.122 get disks --insecure
"$TALOS" --nodes 192.168.1.123 get links --insecure
"$TALOS" --nodes 192.168.1.123 get disks --insecure
```

Match exactly:

| Node | Reserved endpoint | Wired MAC | Internal install target |
|---|---:|---|---|
| `rudtal-cp-1` | `192.168.1.121` | `e0:51:d8:12:d2:66` | `/dev/nvme0n1`, 256 GB AirDisk |
| `rudtal-worker-1` | `192.168.1.122` | `e0:51:d8:1a:80:37` | `/dev/nvme0n1`, 512 GB TWSC |
| `rudtal-worker-2` | `192.168.1.123` | `e0:51:d8:1a:83:85` | `/dev/nvme0n1`, 512 GB TWSC |

If an address, MAC, disk model/size or transport does not match, stop and fix
the router/KVM/boot selection. Never substitute `/dev/sda` (installer USB) or
`/dev/sr0` (JetKVM media). Keep installer media mounted only while needed, then
remove/unmount it after the node boots from NVMe.

## Checkpoint 4: reset and reinstall Talos

This crosses the Talos lifecycle boundary. `reset` wipes the named EPHEMERAL and
STATE partitions, including container data and the control-plane etcd state;
`--reboot` returns the node to maintenance mode. It is destructive but repeatable
only after the node identity and disk match above. Recovery is to boot the
verified installer and re-apply the reviewed machine config.

With the operator watching JetKVM, reset workers first and the control plane last:

```sh
TALOS=downloads/talosctl-v1.12.12-darwin-arm64
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.122 reset --graceful \
  --system-labels-to-wipe EPHEMERAL \
  --system-labels-to-wipe STATE --reboot
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.123 reset --graceful \
  --system-labels-to-wipe EPHEMERAL \
  --system-labels-to-wipe STATE --reboot
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.121 reset --graceful \
  --system-labels-to-wipe EPHEMERAL \
  --system-labels-to-wipe STATE --reboot
```

Once each node is visibly in maintenance mode at the matched endpoint, apply the
reviewed Cilium machine configs. `--insecure` is required only because reset
removed the installed client/server trust state; it writes the selected Talos
configuration and installation disk.

```sh
TALOS=downloads/talosctl-v1.12.12-darwin-arm64
"$TALOS" apply-config --insecure --nodes 192.168.1.121 \
  --file generated/rudtal-cp-1/controlplane.yaml
"$TALOS" apply-config --insecure --nodes 192.168.1.122 \
  --file generated/rudtal-worker-1/worker.yaml
"$TALOS" apply-config --insecure --nodes 192.168.1.123 \
  --file generated/rudtal-worker-2/worker.yaml
```

For each node, verify authenticated Talos `version`, `get systemdisk` and
`services` before moving on. The expected system disk is NVMe and kubelet is
healthy; do not proceed if a node booted installer media or received the wrong
config.

## Checkpoint 5: single fresh etcd bootstrap

A reset created a new cluster generation. Bootstrap etcd exactly once for this
generation, on `rudtal-cp-1` only. It creates the initial etcd member and starts
the Kubernetes API; it is not a health check and must never be repeated on this
generation.

```sh
TALOS=downloads/talosctl-v1.12.12-darwin-arm64
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.121 bootstrap
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.121 health --wait-timeout 10m
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.121 kubeconfig state/kubeconfig --force
```

The kubeconfig path is ignored and credential-bearing; do not display it. The
API may be reachable while nodes remain NotReady because CNI is intentionally
`none`. Start the Cilium exception immediately.

## Checkpoint 6: one-time Cilium bootstrap exception

Cilium is the first pod-network component, so this one Helm install is
imperative by necessity. It changes Kubernetes objects and Helm storage in
`kube-system`, but it is already represented by the branch values and Flux
HelmRelease. Do not run Flux yet and do not use `helm upgrade --install` under a
different release name.

First verify the chart identity without storing or displaying any secret:

```sh
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
helm pull oci://quay.io/cilium/charts/cilium \
  --version "$CILIUM_VERSION" --destination "$tmp_dir" --debug
# The debug digest must equal $CILIUM_CHART_DIGEST.
```

Install the digest-pinned chart with the exact Git values:

```sh
helm install cilium \
  "oci://quay.io/cilium/charts/cilium@$CILIUM_CHART_DIGEST" \
  --namespace kube-system \
  --values infrastructure/controllers/cilium/values.yaml

KUBECONFIG=state/kubeconfig kubectl -n kube-system \
  rollout status daemonset/cilium --timeout=10m
KUBECONFIG=state/kubeconfig kubectl -n kube-system \
  rollout status deployment/cilium-operator --timeout=10m
KUBECONFIG=state/kubeconfig kubectl get nodes -o wide
```

Expected: three Cilium agents, two operators and all three nodes become healthy.
If this does not happen, inspect only non-secret pod/events/status output and
repair or rebuild before Flux adoption. Do not proceed with a partly healthy
CNI.

## Checkpoint 7: restore Flux and hand over Cilium

This command needs cluster-admin access, Git push rights and approval to create
the Flux deploy-key Secret. The command creates/updates Flux controllers and
pushes generated non-secret manifests to the experiment branch; it does not
merge to `main`. Never display the generated Secret.

```sh
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" bootstrap git \
  --url=ssh://git@github.com/danquah/rudtal.git \
  --branch=experiment/cilium-s07 \
  --path=clusters/rudtal \
  --version=v2.9.5 \
  --network-policy=true \
  --watch-all-namespaces=true
```

If bootstrap reports that the existing branch files differ, stop and compare
only the reviewed non-secret Git diff. Do not use `--force` until ownership and
branch are understood. Bootstrap must leave `gotk-sync.yaml` pointing at
`experiment/cilium-s07`, not `main`.

Wait for the source and dependency chain:

```sh
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" check
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" get sources git -A
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" get sources oci -A
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" get kustomizations -A
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" get helmreleases -A
KUBECONFIG=state/kubeconfig kubectl -n kube-system get helmrelease cilium
helm status cilium -n kube-system
```

The expected adoption evidence is a Ready `infra-cilium` Kustomization and
Ready `kube-system/cilium` HelmRelease with release identity `cilium` in
`kube-system`. The first Flux action is expected to be an upgrade that adopts
and reconciles the existing release. Do not install a second release.

### Adoption failure recovery

If the HelmRelease is not Ready:

1. Suspend only `infra-cilium` so it stops retrying; leave Flux itself running.
2. Inspect HelmRelease conditions/events and ordinary object metadata. Never
   print Secret data or use `kubectl get secret -o yaml`.
3. Confirm chart digest, values ConfigMap, `releaseName`, `targetNamespace` and
   `storageNamespace` match this branch.
4. If the disposable release must be recreated, uninstall it while the owner is
   suspended, run the exact digest-pinned `helm install` once, then resume the
   Kustomization and reconcile it.

```sh
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" suspend kustomization \
  infra-cilium -n flux-system
# repair only after reviewing the non-secret failure
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" resume kustomization \
  infra-cilium -n flux-system
KUBECONFIG=state/kubeconfig "$HOME/bin/flux" reconcile kustomization \
  infra-cilium -n flux-system --with-source
```

Do not delete the Flux credential Secret, do not change Helm identity fields,
and do not use `--force` as a substitute for resolving ownership.

## Checkpoint 8: networking acceptance tests

Run these after Flux adoption. The test namespace is disposable. Cilium's
connectivity test may need a privileged PodSecurity label on a separate test
namespace; do not weaken the cluster-wide policy.

### Agents, operator and datapath

```sh
KUBECONFIG=state/kubeconfig kubectl -n kube-system get pods -l k8s-app=cilium -o wide
KUBECONFIG=state/kubeconfig kubectl -n kube-system get pods -l io.cilium/app=operator -o wide
KUBECONFIG=state/kubeconfig kubectl -n kube-system get ciliumnodes
# If the separately reviewed Cilium CLI is installed, this optional check may
# be run; the Kubernetes object checks above are the required evidence.
# KUBECONFIG=state/kubeconfig cilium status --wait
```

Record that the agent is a DaemonSet on all three nodes and that kube-proxy is
still present. Do not claim kube-proxy replacement.

### Pod-to-pod, Service and DNS

```sh
KUBECONFIG=state/kubeconfig kubectl create namespace s07-nettest
KUBECONFIG=state/kubeconfig kubectl label namespace s07-nettest \
  pod-security.kubernetes.io/enforce=privileged --overwrite
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest create deployment echo \
  --image=nginx:1.27-alpine
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest expose deployment echo \
  --name=echo --port=80 --target-port=80
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest run client \
  --image=busybox:1.36.1 --labels=app=client --restart=Never \
  --command -- sleep 3600
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest wait \
  --for=condition=Available deployment/echo --timeout=180s
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest wait \
  --for=condition=Ready pod/client --timeout=180s
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest exec client -- \
  nslookup kubernetes.default.svc.cluster.local
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest exec client -- \
  wget -qO- http://echo/
```

For direct pod-to-pod evidence, get the echo Pod IP without displaying any
credential-bearing object and request that IP from `client`:

```sh
ECHO_IP=$(KUBECONFIG=state/kubeconfig kubectl -n s07-nettest \
  get pods -l app=echo -o jsonpath='{.items[0].status.podIP}')
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest exec client -- \
  wget -qO- "http://${ECHO_IP}/"
```

### NodePort through retained kube-proxy

```sh
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest expose deployment echo \
  --name=echo-nodeport --type=NodePort --port=80 --target-port=80
NODEPORT=$(KUBECONFIG=state/kubeconfig kubectl -n s07-nettest \
  get service echo-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
for node in 192.168.1.121 192.168.1.122 192.168.1.123; do
  curl --fail --max-time 10 "http://${node}:${NODEPORT}/"
done
```

Record the assigned port and the HTTP result from every node. This first pass
expects kube-proxy to provide the Service/NodePort path.

### CiliumNetworkPolicy allow/deny

Apply a temporary policy selecting the echo pods and allowing only the labeled
client:

```sh
KUBECONFIG=state/kubeconfig kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: echo-client-only
  namespace: s07-nettest
spec:
  endpointSelector:
    matchLabels:
      app: echo
  ingress:
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: s07-nettest
            app: client
EOF
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest run blocked \
  --image=busybox:1.36.1 --labels=app=blocked --restart=Never \
  --command -- sleep 3600
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest wait \
  --for=condition=Ready pod/blocked --timeout=180s
KUBECONFIG=state/kubeconfig kubectl -n s07-nettest exec client -- \
  wget -qO- --timeout=5 http://echo/
! KUBECONFIG=state/kubeconfig kubectl -n s07-nettest exec blocked -- \
  wget -qO- --timeout=5 http://echo/
```

The client request must succeed and the blocked request must fail or time out.
Delete the temporary namespace after recording results:

```sh
KUBECONFIG=state/kubeconfig kubectl delete namespace s07-nettest --wait=true
```

## Rollback: rebuild the recorded Flannel baseline

Rollback is another deliberate fresh cluster generation, not an in-place CNI
migration. Suspend or remove the experiment Flux path only after recording the
failure, then use a temporary worktree at `BASELINE_COMMIT`:

```sh
git worktree add /tmp/rudtal-flannel-baseline "$BASELINE_COMMIT"
```

From that worktree, render and strictly validate with the normal Flannel patches
(no `EXTRA_CONFIG_PATCH`), then repeat the physical endpoint/MAC/disk match,
reset/reinstall, and authenticated Talos checks. Bootstrap etcd exactly once on
the new generation, retrieve a fresh ignored kubeconfig, and restore Flux from
`main` at the recorded baseline. Verify three Flannel pods, three kube-proxy
pods, Ready nodes, CoreDNS, Flux source/Kustomizations and the baseline workload
contract. Remove the temporary worktree only after the recovery evidence is
recorded.

A successful rollback restores the known-good Flannel datapath and leaves the
Cilium experiment branch available for review. It does not merge the experiment,
create a tag, or alter the main-branch history.

## S07B stop condition

The rebuild is complete only when all acceptance tests, Flux adoption evidence
and cleanup are recorded, or the Flannel baseline has been rebuilt and verified.
Any failure without a recorded owner, exact command and recovery state is an
incomplete session.
