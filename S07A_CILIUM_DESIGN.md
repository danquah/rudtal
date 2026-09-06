# S07A Cilium rebuild design

Status: corrected offline design only. No Talos node, disk, Kubernetes object,
Flux reconciliation, Git remote, deploy key, or credential was changed during this
review. S07B remains unapproved and unperformed.

## Scope and safety boundary

S07A prepares a disposable fresh-generation rebuild on
`experiment/cilium-s07`. The live cluster remains the known-good Flannel
baseline; its Flux `GitRepository` currently watches `main`. This is not an
in-place CNI migration and does not change Talos or Kubernetes versions.

The experiment retains Talos-managed kube-proxy. Kube-proxy replacement,
KubePrism API overrides, BPF masquerading, direct routes, Hubble, Gateway API
and Tailscale are explicitly out of scope.

## Baseline and branch gate

Read-only evidence recorded on 2026-09-05 found three Ready nodes on Talos
`v1.12.12` and Kubernetes `v1.35.8`, with Flannel, kube-proxy, CoreDNS and all
four Flux controllers healthy. Flux reported `main@sha1:850d7a23`.

At review time, local `main` is `a6233e47ae953940f460c696965fb3114894a51f`,
one documentation commit ahead of `origin/main` (`850d7a23…`), and the
experiment is based on that local main plus its S07 commit. Before S07B, push
that fast-forward-safe local-main commit without rewriting history, wait until
live Flux reports `main@sha1:a6233e47`, and use it as the Flannel rollback
anchor:

```text
BASELINE_COMMIT=a6233e47ae953940f460c696965fb3114894a51f
```

Then push the reviewed experiment commit normally so Flux can fetch it during
the fresh bootstrap. Do not merge it to `main` before the experiment succeeds,
force-push either branch, or create a baseline tag.

A failed experiment is recovered by a new Flannel generation from a detached
worktree at `BASELINE_COMMIT`; it is never repaired by swapping CNIs in place.

## Compatibility and supply-chain decision

Cilium `1.18.13` is rejected for this experiment. Its Helm `kubeVersion`
range establishes only chart metadata, not the upstream e2e-tested Kubernetes
versions. On 2026-09-06, the current stable Cilium release is `1.20.1`; its
upstream compatibility matrix explicitly lists Kubernetes `1.35` among the
e2e-tested and guaranteed-compatible versions. Kubernetes remains `1.35.8` and
Talos remains `v1.12.12`.

The selected OCI artifact is:

| Item | Pinned value | Review evidence |
|---|---|---|
| Chart | `oci://quay.io/cilium/charts/cilium:1.20.1` | upstream OCI Helm installation guide |
| OCI manifest | `sha256:906ce40d35daad838d12add8a5ba7033e767767f51799a93c7eace2cec9cdc05` | Helm 3.19.0 pull, 2026-09-06 |
| Chart layer | `sha256:06210eef7c23d15f7699c79e2fe3a1ec9c389024c5c5c006ea04022d322449a2` | OCI manifest returned by that pull |
| Cosign identity | `https://github.com/cilium/cilium/.*` | Cilium OCI signing guide |
| Cosign issuer | `https://token.actions.githubusercontent.com` | Cilium OCI signing guide |
| Agent | `quay.io/cilium/cilium:v1.20.1@sha256:ae9ea21f7427fe24bc6ea7247eb552157a1b0a431744045d3f641545ca71d11b` | immutable upstream `v1.20.1` release |
| Generic operator | `quay.io/cilium/operator:v1.20.1@sha256:6c3885fc7b629099fdbe2a5c87869c86feb825fa18fae299eac0f61918d16ecf` | immutable upstream `v1.20.1` release |
| Envoy | `quay.io/cilium/cilium-envoy:v1.37.5-1786810558-766ccfb37260a43e9d228837aa84ce3faf9f64e7@sha256:75b8094c7127736a2ffd2dce3945e0931cb6df21b0372ff661940eca26730b91` | chart defaults and upstream `v1.20.1` release |

`infrastructure/controllers/cilium/cilium-source.yaml` pins the manifest and
requires Flux source-controller to verify this issuer and identity. The values
file pins every image that this selected configuration renders. OCI pull,
manifest/layer inspection, and Cosign verification are artifact-only checks;
they do not contact the Kubernetes API. On 2026-09-06, a temporary Cosign
`v3.1.3` Darwin arm64 executable SHA-256 matched the upstream checksum and
`cosign verify` exited successfully for this chart. It validated the claims,
trusted signing certificate and offline transparency-log inclusion; its returned
manifest digest exactly matched the pin above. S07B repeats the same local
artifact check immediately before the cluster-facing Helm install.

## Talos and Helm values

The Talos v1.12 Cilium patch remains deliberately narrow:

```yaml
cluster:
  network:
    cni:
      name: none
```

`cluster.proxy.disabled` is absent: this preserves kube-proxy. The patch is
applied after `talos/patches/common.yaml`, so it only replaces Flannel's CNI
choice. It preserves the endpoint, DHCP, pod CIDR, service CIDR and DNS
configuration.

The `1.20.1` chart was pulled and its values and rendered manifests were
reviewed. The retained settings have these purposes:

| Value | Decision |
|---|---|
| `ipam.mode: kubernetes` | Cilium consumes Kubernetes-assigned PodCIDRs, as Talos requires. |
| `kubeProxyReplacement: false` | kube-proxy retains Service and NodePort handling. |
| `routingMode: tunnel`, `tunnelProtocol: vxlan`, `autoDirectNodeRoutes: false` | avoid assumptions about direct L2 routing on the shared LAN. |
| `bpf.autoMount.enabled: false`, `bpf.root: /sys/fs/bpf` | consume Talos-provided bpffs. |
| `cgroup.autoMount.enabled: false`, `cgroup.hostRoot: /sys/fs/cgroup` | consume Talos-provided cgroup v2. |
| agent and clean-state capability lists | omit `SYS_MODULE`; Talos does not allow workload module loading. |
| `operator.replicas: 2` | explicit chart default; Cilium's required tolerations permit bootstrap while nodes are NotReady. |

The selected `1.20.1` chart continues to support all values above. It also
defaults to a standalone Envoy DaemonSet for a new installation, so the Envoy
image is pinned even though Gateway API and Hubble remain disabled. The Talos
guide's kube-proxy configuration does not require `bpf.masquerade`; it remains
unset. DNS must be tested before policy work because Talos warns that host DNS
forwarding combined with BPF masquerading is unsafe.

## Bootstrap window, not premature health

With CNI `none`, Talos reaches the Kubernetes API but nodes remain NotReady.
The Talos guide describes this as its bootstrap window and says node readiness
retries after about ten minutes. Therefore S07B uses this order:

1. Apply the reviewed no-CNI machine configuration and bootstrap etcd exactly
   once for this fresh generation.
2. Check only etcd and API availability: authenticated `talosctl service etcd`
   and `service apid`, retrieve the ignored kubeconfig, then Kubernetes
   `/readyz`. Do **not** run full `talosctl health` or require Ready nodes yet.
3. Install the exact Cilium OCI chart immediately with the ignored
   `state/kubeconfig` explicitly selected.
4. Wait for Cilium, its operators and all nodes to be Ready; only then run full
   Talos and Kubernetes health and the functional tests.

This is a one-time bootstrap exception. It has the same release identity,
chart, digest and values that Flux later reconciles.

## Flux ownership and deterministic adoption

The three Helm identity fields are fixed:

- `releaseName: cilium` is the Helm release name.
- `targetNamespace: kube-system` is where Helm applies Cilium resources.
- `storageNamespace: kube-system` is where Helm stores that release's revision
  records (normally Helm Secrets). Changing it makes helm-controller uninstall
  the old stored release before installing in the new namespace.

The `HelmRelease` and the imperative `helm install` use all three. The
helm-controller documentation says it uses release name and values to locate
and reconcile the release; its first action on an existing release may be an
upgrade. This must be observed, not presumed: record `helm status` and `helm
history` before handoff, then prove the HelmRelease becomes Ready with a
recorded `upgrade`/successful reconciliation and the same storage namespace.

`install.disableTakeOwnership: false` and
`upgrade.disableTakeOwnership: false` allow Helm to take ownership of existing
**resources** during those Helm actions. They do not transfer release storage
or prove that helm-controller has adopted a release made by the Helm CLI.

If the HelmRelease is not Ready, suspend the HelmRelease before changing
anything and leave the known-good imperative Cilium release installed. Inspect
only ordinary HelmRelease status, events, release status/history and
non-secret resource metadata. Do not uninstall Cilium as an adoption remedy:
that could leave the cluster without a CNI. If an exact imperative `helm
upgrade` is required, perform it only while the HelmRelease is suspended,
using the same digest, values, release name and kubeconfig; verify Cilium stays
healthy, then resume the HelmRelease. Rebuild Flannel only if the CNI itself
fails acceptance.

## Promotion after a successful experiment

Do not change the Flux source branch until the experiment's source,
Kustomizations and HelmRelease are all Ready. Promotion has two Git branches
and one live source; their sequence avoids a branch-reference loop:

1. Merge the reviewed Cilium experiment state into `main` without rewriting
   either history and push `main`. At this point the live source still watches
   `experiment/cilium-s07`, so it cannot yet be deleted.
2. On `main`, commit the generated `clusters/rudtal/flux-system/gotk-sync.yaml`
   change from `ref.branch: experiment/cilium-s07` to `ref.branch: main` and
   push it. Apply that same handoff commit to the still-watched experiment
   branch and push it. Both branches now declare that the source should watch
   `main`; no branch points back to the other.
3. Reconcile the live `flux-system` GitRepository from the experiment branch
   and wait until its observed artifact changes to the recorded `main@sha1`.
   Then verify Flux, every Kustomization, the OCIRepository and
   `kube-system/cilium` HelmRelease are Ready. This proves the live control
   plane now follows main rather than merely that main contains the files.
4. Rotate credentials safely: first register a newly generated, read-only
   GitHub deploy key. Update the in-cluster `flux-system` Git credential with
   `flux create secret git` using the explicit kubeconfig, reconcile the
   GitRepository, and prove the new credential fetches `main`. Never display
   the Secret. Only then remove the old experiment deploy key from GitHub.
5. Delete the remote experiment branch only after the main artifact and new
   credential have remained Ready through a reconciliation interval. Delete
   the local branch only when no worktree uses it.

The final source branch must be `main`, not an experiment commit that refers
back to itself. Retiring the old key before the replacement source fetch is
verified would strand Flux.

## Cilium policy and networking proof

The test must prove different datapath paths, not merely pod co-location.
S07B creates a server Pod pinned to `rudtal-worker-1` and client/blocked Pods
pinned to `rudtal-worker-2`, checks their `.spec.nodeName` values, then uses
the server Pod IP for direct pod-to-pod traffic. It separately checks the
server's ClusterIP Service, DNS, and NodePort from each LAN node address.

The temporary CiliumNetworkPolicy is namespaced to `s07-nettest`. Its
`endpointSelector` selects only local `app: cross-node-server` endpoints;
CiliumNetworkPolicy namespace scope supplies the destination namespace. Its
`fromEndpoints` selector must use Cilium's documented identity label
`k8s:io.kubernetes.pod.namespace: s07-nettest`, plus `app: allowed-client`.
The unprefixed namespace label in the earlier proposal was incorrect. The
allowed cross-node request must succeed; a distinct cross-node `blocked-client`
request must time out or fail. Deleting the namespace removes the policy and
all tests.

## Offline validation contract

Before approval, S07A must pass local shell syntax and ShellCheck for scripts,
Kustomize/YAML validation, chart pull/lint/template with the selected digest
and values, image-reference assertions from the rendered manifest, link
checking, and strict pinned Talos validation of all three generated configs.
Generated configs and kubeconfigs are credential-bearing and are never
displayed. Client-only checks must not silently perform live discovery.

## References accessed 2026-09-06

- [Cilium Kubernetes compatibility](https://docs.cilium.io/en/stable/network/kubernetes/compatibility/)
- [Cilium Helm OCI installation and Cosign verification](https://docs.cilium.io/en/stable/installation/k8s-install-helm/)
- [Cilium 1.20 Helm reference](https://docs.cilium.io/en/v1.20/helm-reference/)
- [Cilium 1.20.1 immutable release](https://github.com/cilium/cilium/releases/tag/v1.20.1)
- [Talos Cilium guide](https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium)
- [Talos v1.12 CLI reference](https://docs.siderolabs.com/talos/v1.12/reference/cli/)
- [Flux HelmRelease documentation](https://fluxcd.io/flux/components/helm/helmreleases/)
- [Flux Helm API](https://fluxcd.io/flux/components/helm/api/v2/)
- [Flux GitRepository documentation](https://fluxcd.io/flux/components/source/gitrepositories/)
- [Cilium namespace-policy semantics](https://docs.cilium.io/en/stable/security/policy/kubernetes/)
