# S07B Cilium physical rebuild runbook

This is a destructive, operator-present procedure. It is not authorized or
executed by S07A. Stop at any failed checkpoint; recover with a fresh Flannel
rebuild, never an in-place CNI swap.

## Fixed inputs and preflight gates

```sh
. ./versions.env
BRANCH=experiment/cilium-s07
BASELINE_COMMIT=a6233e47ae953940f460c696965fb3114894a51f
TALOS=downloads/talosctl-v1.12.12-darwin-arm64
KUBECONFIG_PATH=state/kubeconfig
CONTROL_PLANE=192.168.1.121
WORKER_1=192.168.1.122
WORKER_2=192.168.1.123
```

Do not start until the operator and reviewer approve the final experiment
commit, exact values/digests, workload and node-local-storage disposal,
destructive reset, and Flannel rollback. Confirm the review workstation has the
pinned `talosctl`, Helm, Flux CLI and Cosign with access to Sigstore
transparency services. S07A verified this chart's pinned manifest with Cosign
v3.1.3; repeat the Checkpoint 6 artifact-only verification immediately before
the cluster-facing Helm install.

`reset` changes Talos STATE and EPHEMERAL partitions, erases the current etcd
cluster, and returns a node to maintenance mode. Recovery is the reviewed
machine configuration applied to the verified internal NVMe. Before that
operation, the operator must be present at JetKVM and understand that it is
repeatable only after the endpoint, wired MAC and install disk match.

## Checkpoint 0: publish the already-reviewed Git inputs

This checkpoint changes remote Git only; it does not touch a node or cluster.
The current live Flux source watches `main`, which is one local documentation
commit behind local `main`. Push it first, wait for the live source to report
that commit, then publish the reviewed experiment branch without force:

```sh
git fetch origin --prune
git switch main
git status --short --branch
git push origin main
git switch "$BRANCH"
git status --short --branch
git merge-base --is-ancestor main HEAD
git push --set-upstream origin "$BRANCH"
```

Record both remote commit IDs. `main` must contain
`$BASELINE_COMMIT`, and the experiment must contain it before Cilium is
bootstrapped. Do not merge Cilium to main yet, create a tag, or use `--force`.

## Checkpoint 1: record the healthy Flannel baseline

These are read-only Kubernetes checks. They inspect existing state but never
print Secret data. The expected result is three Ready nodes, Flannel and
kube-proxy healthy, Flux Ready at `main@sha1:a6233e47`, no Cilium, and no
workload or persistent state that has not been declared disposable.

```sh
KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes -o wide
KUBECONFIG="$KUBECONFIG_PATH" kubectl get pods -n kube-system -o wide
KUBECONFIG="$KUBECONFIG_PATH" kubectl get pods -n flux-system -o wide
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" get sources git -A
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" get kustomizations -A
KUBECONFIG="$KUBECONFIG_PATH" kubectl get pvc -A
KUBECONFIG="$KUBECONFIG_PATH" kubectl get pods -A -l k8s-app=cilium --no-headers
```

If a PVC, local volume or workload matters, stop and preserve it through its
reviewed mechanism. No local volume survives the reset.

## Checkpoint 2: render and validate only local inputs

This layer composes Talos configurations. It decrypts only into ignored local
storage; never display, diff or commit a generated config or kubeconfig.

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

The expected result is three strict-metal validations. A failure means correct
the reviewed source and repeat this local checkpoint; do not apply a partially
reviewed config.

## Checkpoint 3: prove the installed-node identities before reset

This is read-only Talos machine-API discovery using authenticated access from
the rendered control-plane talosconfig. It proves the currently installed
machines are the three intended nodes before any state is erased. Compare the
endpoint, wired MAC, installed system disk, model and size with `INVENTORY.md`:

```sh
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" version
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" get links
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" get disks
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" get systemdisk
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_1" get links
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_1" get disks
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_1" get systemdisk
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_2" get links
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_2" get disks
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_2" get systemdisk
```

| Node | Endpoint | Wired MAC | Internal system disk |
|---|---|---|---|
| `rudtal-cp-1` | `192.168.1.121` | `e0:51:d8:12:d2:66` | `/dev/nvme0n1`, 256 GB AirDisk |
| `rudtal-worker-1` | `192.168.1.122` | `e0:51:d8:1a:80:37` | `/dev/nvme0n1`, 512 GB TWSC |
| `rudtal-worker-2` | `192.168.1.123` | `e0:51:d8:1a:83:85` | `/dev/nvme0n1`, 512 GB TWSC |

Any mismatch stops the procedure. Never substitute the installer USB `/dev/sda`
or JetKVM media `/dev/sr0`.

## Checkpoint 4: reset workers, then control plane

Talos v1.12.12 `reset --help` confirms `--graceful`, repeated
`--system-labels-to-wipe`, `--reboot`, and the default wait behavior. The two
explicit labels limit the reset to Talos `EPHEMERAL` and `STATE`; do not add
`--user-disks-to-wipe`. `--graceful` asks Kubernetes to cordon/drain and has
special etcd-leave handling before the node is erased. Reset workers first, then
the sole control plane:

```sh
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_1" reset --graceful \
  --system-labels-to-wipe EPHEMERAL \
  --system-labels-to-wipe STATE --reboot
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$WORKER_2" reset --graceful \
  --system-labels-to-wipe EPHEMERAL \
  --system-labels-to-wipe STATE --reboot
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" reset --graceful \
  --system-labels-to-wipe EPHEMERAL \
  --system-labels-to-wipe STATE --reboot
```

After each reset, verify maintenance mode at the matched address using the
pinned client and `--insecure`; recheck the MAC and disk before applying a
config:

```sh
"$TALOS" --nodes "$CONTROL_PLANE" version --insecure
"$TALOS" --nodes "$CONTROL_PLANE" get links --insecure
"$TALOS" --nodes "$CONTROL_PLANE" get disks --insecure
"$TALOS" --nodes "$WORKER_1" version --insecure
"$TALOS" --nodes "$WORKER_1" get links --insecure
"$TALOS" --nodes "$WORKER_1" get disks --insecure
"$TALOS" --nodes "$WORKER_2" version --insecure
"$TALOS" --nodes "$WORKER_2" get links --insecure
"$TALOS" --nodes "$WORKER_2" get disks --insecure
```

Use JetKVM or installer media only if a reset node does not reach maintenance
mode at its reserved address or cannot boot its internal disk. It is a recovery
path, not a precondition. Remove or unmount installer media after the reviewed
configuration has installed Talos to the NVMe.

## Checkpoint 5: apply and create exactly one new etcd generation

`apply-config --insecure` is now appropriate because reset removed machine
trust. It writes the reviewed machine configuration and triggers installation
to its selected disk:

```sh
"$TALOS" apply-config --insecure --nodes "$CONTROL_PLANE" \
  --file generated/rudtal-cp-1/controlplane.yaml
"$TALOS" apply-config --insecure --nodes "$WORKER_1" \
  --file generated/rudtal-worker-1/worker.yaml
"$TALOS" apply-config --insecure --nodes "$WORKER_2" \
  --file generated/rudtal-worker-2/worker.yaml
```

After the installed Talos API is reachable, verify authenticated version and
system disk on all nodes. Bootstrap only the control plane, exactly once for
this new generation:

```sh
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" bootstrap
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" service etcd
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" service apid
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" kubeconfig "$KUBECONFIG_PATH" --force
KUBECONFIG="$KUBECONFIG_PATH" kubectl get --raw='/readyz'
```

The expected result is running etcd/APId and API `/readyz` success. Nodes are
expected to remain NotReady with CNI `none`. Do **not** run full `talosctl
health`, wait for Ready nodes, or bootstrap again; install Cilium in the Talos
bootstrap window now.

## Checkpoint 6: verify artifact, then install the only CNI

These are local registry and artifact checks. They do not use a kubeconfig and
cannot mutate the cluster. The commands fail unless Helm resolves the reviewed
manifest digest, the downloaded chart bytes match the reviewed layer digest,
and Cosign verifies that exact manifest using Cilium's documented keyless
issuer and identity:

```sh
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
helm_output=$(helm pull oci://quay.io/cilium/charts/cilium \
  --version "$CILIUM_VERSION" --destination "$tmp_dir" 2>&1)
printf '%s\n' "$helm_output"
printf '%s\n' "$helm_output" | grep -F \
  "Digest: $CILIUM_CHART_DIGEST" >/dev/null
printf '%s  %s\n' "${CILIUM_CHART_LAYER_DIGEST#sha256:}" \
  "$tmp_dir/cilium-${CILIUM_VERSION}.tgz" | shasum -a 256 --check -
cosign verify \
  --certificate-identity-regexp='https://github.com/cilium/cilium/.*' \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  "quay.io/cilium/charts/cilium@${CILIUM_CHART_DIGEST}"
helm lint "$tmp_dir/cilium-${CILIUM_VERSION}.tgz" \
  --values infrastructure/controllers/cilium/values.yaml
helm template cilium "$tmp_dir/cilium-${CILIUM_VERSION}.tgz" \
  --namespace kube-system \
  --values infrastructure/controllers/cilium/values.yaml > "$tmp_dir/cilium.yaml"
```

Only after all artifact checks succeed, this command mutates Kubernetes. Its
explicit kubeconfig, release name, target namespace and values must exactly
match the HelmRelease:

```sh
helm install cilium \
  "oci://quay.io/cilium/charts/cilium@${CILIUM_CHART_DIGEST}" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --namespace kube-system \
  --values infrastructure/controllers/cilium/values.yaml

KUBECONFIG="$KUBECONFIG_PATH" kubectl -n kube-system \
  rollout status daemonset/cilium --timeout=10m
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n kube-system \
  rollout status deployment/cilium-operator --timeout=10m
KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes -o wide
```

Expected: three Cilium agents, two operators, and three Ready nodes. Now—and
only now—run full authenticated Talos health and Kubernetes-system checks:

```sh
"$TALOS" --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes "$CONTROL_PLANE" health \
  --control-plane-nodes "$CONTROL_PLANE" \
  --worker-nodes "$WORKER_1,$WORKER_2" \
  --wait-timeout 10m
KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes -o wide
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n kube-system get pods -o wide
```

Talos health verifies the host services and Kubernetes control plane after the
CNI has made every node Ready. The pod listing must show CoreDNS, kube-proxy,
Cilium, Cilium Envoy and both Cilium operators healthy before Flux bootstrap.

## Checkpoint 7: bootstrap Flux and verify release reconciliation

This changes Kubernetes objects and creates/updates the cluster-only Git
credential. It requires operator approval for the GitHub deploy key. The
explicit kubeconfig selects only the fresh cluster. Do not display the
credential Secret or use `--force`.

```sh
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" bootstrap git \
  --url=ssh://git@github.com/danquah/rudtal.git \
  --branch="$BRANCH" \
  --path=clusters/rudtal \
  --version=v2.9.5 \
  --network-policy=true \
  --watch-all-namespaces=true

helm status cilium --kubeconfig "$KUBECONFIG_PATH" --namespace kube-system
helm history cilium --kubeconfig "$KUBECONFIG_PATH" --namespace kube-system
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" check
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" get sources git -A
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" get sources oci -A
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" get kustomizations -A
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" get helmreleases -A
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n kube-system get helmrelease cilium
```

Acceptance requires the experiment source, `infra-cilium` and
`kube-system/cilium` HelmRelease to report Ready, a Helm history that records
the controller's reconciliation of release `cilium` in storage namespace
`kube-system`, and a still-healthy Cilium DaemonSet. This is the required proof
of Helm CLI/Flux behavior, not an assumption derived from matching names.

### Adoption failure recovery

Keep Cilium running. Suspend the HelmRelease, inspect non-secret status/events
and the matching release history, and preserve a working CNI while repairing:

```sh
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" suspend helmrelease \
  cilium -n kube-system
helm status cilium --kubeconfig "$KUBECONFIG_PATH" --namespace kube-system
helm history cilium --kubeconfig "$KUBECONFIG_PATH" --namespace kube-system
# If required, while the HelmRelease remains suspended, run only this exact
# rolling reconciliation; do not uninstall Cilium.
helm upgrade cilium \
  "oci://quay.io/cilium/charts/cilium@${CILIUM_CHART_DIGEST}" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --namespace kube-system \
  --values infrastructure/controllers/cilium/values.yaml
KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" resume helmrelease \
  cilium -n kube-system
```

If the CNI itself cannot become healthy, stop and use the fresh Flannel rollback
below. Never use `helm uninstall` as a release-takeover fix.

## Checkpoint 8: networking and policy acceptance

The namespace is disposable. Each test Pod is pinned to a different named
worker, so `.spec.nodeName` proves the direct pod test crosses nodes.

```sh
KUBECONFIG="$KUBECONFIG_PATH" kubectl create namespace s07-nettest
KUBECONFIG="$KUBECONFIG_PATH" kubectl label namespace s07-nettest \
  pod-security.kubernetes.io/enforce=privileged --overwrite
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cross-node-server
  labels:
    app: cross-node-server
spec:
  nodeName: rudtal-worker-1
  containers:
    - name: nginx
      image: nginx:1.27-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: allowed-client
  labels:
    app: allowed-client
spec:
  nodeName: rudtal-worker-2
  containers:
    - name: busybox
      image: busybox:1.36.1
      command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: blocked-client
  labels:
    app: blocked-client
spec:
  nodeName: rudtal-worker-2
  containers:
    - name: busybox
      image: busybox:1.36.1
      command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Service
metadata:
  name: cross-node
spec:
  selector:
    app: cross-node-server
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: cross-node-nodeport
spec:
  type: NodePort
  selector:
    app: cross-node-server
  ports:
    - port: 80
      targetPort: 80
EOF
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest wait \
  --for=condition=Ready pod/cross-node-server pod/allowed-client pod/blocked-client \
  --timeout=180s
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest get pods -o wide
```

Record that the server is on `rudtal-worker-1` and clients on
`rudtal-worker-2`; any other placement invalidates the cross-node proof.

```sh
SERVER_IP=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest \
  get pod cross-node-server -o jsonpath='{.status.podIP}')
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest exec allowed-client -- \
  wget -qO- "http://${SERVER_IP}/"
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest exec allowed-client -- \
  wget -qO- http://cross-node/
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest exec allowed-client -- \
  nslookup kubernetes.default.svc.cluster.local
NODEPORT=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest \
  get service cross-node-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
for node in "$CONTROL_PLANE" "$WORKER_1" "$WORKER_2"; do
  curl --fail --max-time 10 "http://${node}:${NODEPORT}/"
done
```

The direct Pod IP, ClusterIP Service and DNS each prove a different CNI path.
The three NodePort responses prove the retained kube-proxy service path.

Apply the namespaced CiliumNetworkPolicy only after the allow-path baseline is
recorded. `endpointSelector` is implicitly restricted to the policy namespace;
`fromEndpoints` must use the documented `k8s:` prefix for the Kubernetes
namespace identity label.

```sh
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: cross-node-server-allowed-client-only
spec:
  endpointSelector:
    matchLabels:
      app: cross-node-server
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: s07-nettest
            app: allowed-client
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
EOF
KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest exec allowed-client -- \
  wget -qO- --timeout=5 "http://${SERVER_IP}/"
! KUBECONFIG="$KUBECONFIG_PATH" kubectl -n s07-nettest exec blocked-client -- \
  wget -qO- --timeout=5 "http://${SERVER_IP}/"
KUBECONFIG="$KUBECONFIG_PATH" kubectl delete namespace s07-nettest --wait=true
```

Cilium's default policy mode allows endpoints until selected; this ingress rule
selects the server and therefore permits only the listed source/port. The
allowed cross-node request must succeed and blocked cross-node request must
fail or time out. Namespace deletion removes all disposable policy/test state.

## Checkpoint 9: promote only after stable experiment evidence

After all experiment checks remain Ready for one reconciliation interval:

1. Merge the reviewed experiment into `main` and push it normally.
2. Commit `gotk-sync.yaml` with `ref.branch: main` on main and push. Apply the
   same handoff commit to the still-watched experiment branch and push. Both
   branches now name main, avoiding a reference loop.
3. Reconcile the live GitRepository while it still fetches the experiment
   handoff commit, then wait for its artifact to become `main@sha1:<merged>`. Verify
   Flux, all Kustomizations, OCI source and Cilium HelmRelease remain Ready.
4. Create a fresh read-only deploy credential before retiring the experiment
   credential. This changes the GitHub credential layer and the cluster-only
   `flux-system` Secret; it does not change Git-managed workloads. Generate the
   protected key under ignored `state/`, register only its public half in the
   GitHub UI with read-only access, then update the Secret and prove it can
   fetch `main` without displaying either private key or Secret:

   ```sh
   ssh-keygen -q -t ed25519 -N '' -f state/flux-main-deploy-key
   KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" create secret git flux-system \
     --url=ssh://git@github.com/danquah/rudtal.git \
     --private-key-file=state/flux-main-deploy-key \
     --namespace=flux-system
   KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" reconcile source git \
     flux-system -n flux-system
   KUBECONFIG="$KUBECONFIG_PATH" "$HOME/bin/flux" get sources git -A
   ```

   Success is a Ready `flux-system` GitRepository at the expected `main@sha1`
   revision. If it fails, retain the old experiment deploy key and restore its
   still-valid credential; do not remove either credential before a successful
   source fetch.
5. After a successful main fetch and stable reconciliation, remove the old
   experiment deploy key in GitHub, then delete the remote experiment branch.

## Rollback: fresh Flannel baseline generation

If Cilium cannot meet acceptance, use a detached worktree at the recorded
baseline and repeat identity verification, worker-first reset, maintenance
verification, configuration apply, and exactly one bootstrap for that fresh
generation:

```sh
git worktree add /tmp/rudtal-flannel-baseline "$BASELINE_COMMIT"
```

Render there without `EXTRA_CONFIG_PATCH`, validate strictly, bootstrap once,
retrieve a fresh ignored kubeconfig, and restore Flux from `main`. Verify three
Flannel pods, three kube-proxy pods, three Ready nodes, CoreDNS, Flux and the
baseline workload contract. Remove the temporary worktree only after recorded
recovery evidence. Do not delete Cilium imperatively while trying to fix
adoption; rollback is the only destructive CNI recovery path.

## Stop condition

S07B is complete only when the complete Cilium acceptance record and promotion
are stable, or the Flannel baseline has been rebuilt and verified. Any failed
checkpoint requires its observed state, exact non-secret command, owner and
recovery path recorded in `STATUS.md` and `LEARNING_LOG.md`.
