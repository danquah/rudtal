# S07A Cilium rebuild design

Status: reviewable offline design only. No Talos node, disk, Kubernetes object or
running Flux reconciliation was changed in S07A.

## Scope and safety boundary

S07A prepares the first Cilium rebuild experiment on the isolated branch
`experiment/cilium-s07`. The current cluster remains the known-good Flannel
cluster. Flux on the live cluster watches remote `main`; this branch was not
pushed or merged by S07A.

The first pass deliberately keeps Talos-managed `kube-proxy`. Kube-proxy
replacement is a separate experiment and must not be enabled by changing this
design in place.

## Baseline evidence and rollback anchor

Read-only checks on 2026-09-05 established:

- `rudtal-cp-1`, `rudtal-worker-1` and `rudtal-worker-2` are `Ready` on
  Kubernetes `v1.35.8`, Talos `v1.12.12`, kernel `6.18.49-talos`.
- Three `kube-flannel` pods, three `kube-proxy` pods, CoreDNS and all four Flux
  controllers are `Running`.
- Flux source and Kustomizations are `Ready` at
  `main@sha1:850d7a23`; the Cilium label query returned no resources.
- `origin/main` is `850d7a23`; local `main` is `a6233e4`, whose only change is a
  documentation commit on top of `origin/main`. The remote fetch found no
  fast-forward to perform and no history was rewritten.

`850d7a23` is the safe Flannel rollback anchor because it is the Git revision
observed in the live Flux source. S07A creates no Git tag. Before S07B, record
the final experiment commit and keep this baseline commit in the runbook. A
rollback rebuild uses a detached worktree at this commit and the normal Flannel
Talos patches; it does not attempt an in-place CNI swap.

## Compatibility research (accessed 2026-09-05)

| Layer | Evidence | S07 decision |
|---|---|---|
| Talos patch schema | Talos v1.12 patching docs show strategic merge patches and `cluster.network.cni.name: none`; the official Cilium guide says Talos versions before v1.14 use this older field. | Add only `cluster.network.cni.name: none`; do not set `cluster.proxy.disabled`. |
| Talos Cilium requirements | The official Talos Cilium guide requires Kubernetes IPAM, reuse of Talos cgroupv2/bpffs, removal of `SYS_MODULE`, and says Cilium must be installed during the no-CNI bootstrap window. | Values disable Cilium cgroup/bpffs auto-mount and remove the two relevant `SYS_MODULE` capabilities. |
| Host kernel/architecture | Cilium system requirements accept AMD64 and Linux kernel >=5.10; the live Talos nodes report AMD64 hardware and kernel `6.18.49-talos`. | No kernel or Talos extension change is proposed. |
| Kubernetes CNI contract | Kubernetes v1.35 requires a CNI-compatible plugin (CNI v0.4.0 or later; v1.0.0 is recommended). | Cilium supplies the CNI before node readiness is expected. |
| Chart compatibility | The official Cilium `1.18.13` chart metadata declares `kubeVersion: >= 1.21.0-0`; Helm metadata reports chart/app version `1.18.13`. | Render and stage-test against Kubernetes v1.35.8; live connectivity is still the acceptance proof. |
| Cilium release | The immutable upstream `v1.18.13` release publishes the exact agent, generic operator and Envoy image digests used below. | Pin chart manifest and image digests. |
| Talos DNS | The Talos guide warns that `forwardKubeDNSToHost=true` combined with Cilium BPF masquerading can break CoreDNS. | Keep the existing Talos DNS behavior, leave `bpf.masquerade` disabled, and test CoreDNS before policy tests. |

The current Talos `common.yaml` keeps `cluster.network.cni.name: flannel`. The
S07 patch is a later patch in the experiment render command, so the generated
Cilium config overrides only the CNI selection and leaves DNS domain, pod CIDR,
service CIDR, DHCP and kube-proxy behavior unchanged.

## Talos patch and offline rendering

The exact patch is `talos/patches/experiments/cilium-s07.yaml`:

```yaml
cluster:
  network:
    cni:
      name: none
```

`cluster.proxy.disabled` is intentionally absent. The branch version of
`scripts/render.sh` accepts an optional `EXTRA_CONFIG_PATCH` environment value;
without it, existing Flannel rendering is unchanged. S07B renders each node
with:

```sh
EXTRA_CONFIG_PATCH=talos/patches/experiments/cilium-s07.yaml \
  ./scripts/render.sh controlplane rudtal-cp-1
EXTRA_CONFIG_PATCH=talos/patches/experiments/cilium-s07.yaml \
  INSTALL_DISK=/dev/nvme0n1 ./scripts/render.sh worker rudtal-worker-1
EXTRA_CONFIG_PATCH=talos/patches/experiments/cilium-s07.yaml \
  INSTALL_DISK=/dev/nvme0n1 ./scripts/render.sh worker rudtal-worker-2
```

The script writes rendered configs only under ignored `generated/`. Validate
those files with the pinned Talos client; never display them.

## Cilium chart and values

S07 uses the official OCI chart:

- Chart: `cilium`, version `1.18.13`.
- OCI URL: `oci://quay.io/cilium/charts/cilium`.
- OCI manifest digest: `sha256:876b611ff5c63b79d5e8e2621bdbad237ec9089cde72da333df61ff27b55fc81`.
- Chart archive layer digest: `sha256:7d39d95fa5528c31f33eb18d41b78da0ceace9d8c7a81334935cb817c075c32a`.
- Chart signature: Flux verifies the Cosign keyless identity
  `https://github.com/cilium/cilium/.*` from
  `https://token.actions.githubusercontent.com`.

The checked-in values are `infrastructure/controllers/cilium/values.yaml`.
The material settings are:

- `ipam.mode: kubernetes`, so Cilium allocates from Kubernetes node PodCIDRs.
- `kubeProxyReplacement: false`; kube-proxy remains the Service and NodePort
  implementation for this experiment.
- `routingMode: tunnel` and `tunnelProtocol: vxlan`, avoiding a native-route
  assumption on the small shared LAN.
- `bpf.autoMount.enabled: false`, `bpf.root: /sys/fs/bpf`,
  `cgroup.autoMount.enabled: false`, and `cgroup.hostRoot: /sys/fs/cgroup`.
  These consume Talos-provided mounts rather than creating competing mounts.
- The Cilium agent and clean-state capability lists omit `SYS_MODULE`.
- The operator count is explicitly `2`, matching the chart default and allowing
  placement on separate nodes without making operator HA a hidden choice.
- Agent, generic operator and Envoy images use the immutable digests published
  in the Cilium `v1.18.13` release.

The values do not enable kube-proxy replacement, KubePrism API overrides,
BPF masquerading, direct node routes, Hubble relay/UI, Gateway API or Tailscale.
Those are separate decisions. CoreDNS remains the cluster DNS implementation;
DNS is tested after Cilium is healthy.

## OCI versus traditional HelmRepository

OCI is the selected source. Cilium documents OCI as the recommended Helm method:
it avoids a mutable `index.yaml`, supports Cosign chart signatures and permits
manifest-digest pinning. Flux v2's `OCIRepository` plus `HelmRelease.chartRef`
provides the matching GitOps model and is already present in the generated
Flux v2.9.5 CRDs.

A traditional `HelmRepository` at `https://helm.cilium.io/` would be simpler to
inspect with `helm search`, and remains supported, but its normal contract polls
an index and resolves a chart version rather than pinning the OCI manifest. It
would be acceptable if an air-gapped mirror cannot expose OCI, but it is not the
stronger reproducibility choice here.

## Flux declarations and ordering

The branch adds:

```text
infrastructure/controllers/cilium/
├── cilium-source.yaml       # OCIRepository, exact chart manifest digest
├── cilium-release.yaml      # HelmRelease, adoption identity and valuesFrom
├── kustomization.yaml       # namespace and values ConfigMap generator
└── values.yaml              # exact reviewable Helm values
```

`clusters/rudtal/infrastructure.yaml` adds this dependency graph:

```text
infra-controllers (existing Flux controller stage)
        ↓
infra-cilium (Cilium OCIRepository + HelmRelease)
        ↓
infra-configs
        ↓
apps
```

The Cilium HelmRelease is in `kube-system`, as are its source and generated
values ConfigMap. It has `releaseName: cilium`, `targetNamespace: kube-system`
and `storageNamespace: kube-system`; these three identity fields must not be
changed during adoption. CRDs are created on install and replace-upgraded by
Flux. Ownership takeover is explicitly enabled for both install and upgrade.

## Bootstrap exception and Helm adoption

Flux cannot be the first CNI installer when there is no pod network. S07B uses
this one-time sequence on the fresh cluster generation:

1. Talos boots with CNI `none`; kube-proxy is still present. etcd is bootstrapped
   exactly once for this new generation.
2. The operator retrieves a kubeconfig into ignored `state/` and installs the
   exact Cilium chart once with the checked-in values and OCI digest.
3. Cilium agents and the operator become healthy; nodes obtain CNI networking.
4. The operator makes the experiment branch available to GitHub and runs the
   pinned Flux bootstrap command against branch `experiment/cilium-s07`.
5. Flux reconciles `infra-cilium`. The Helm Controller sees the existing Helm
   release with matching identity and performs an upgrade to adopt/reconcile it;
   this is not a metadata-only operation. The first upgrade is expected and is
   verified before any application test.

Flux's documented Helm behavior distinguishes release adoption from object
ownership. Matching Helm release name and namespaces finds the existing release;
the first reconciliation can update its resources and Helm bookkeeping. The
checked-in values must therefore match the imperative install, and no second
`helm install` or second Helm controller may exist.

If adoption fails, suspend only `infra-cilium`, inspect the HelmRelease
conditions/events and the non-secret object ownership metadata, and do not use
`--force`. Because this is a disposable rebuild, the recovery is to keep the
Kustomization suspended, uninstall the failed disposable Cilium release if
needed, reinstall the exact chart/values once, then resume and reconcile. Do
not delete the Flux Git credential or print any Secret.

## S07A offline validation evidence

The branch-local checks completed without touching the cluster:

- `sh -n scripts/render.sh` passed.
- `scripts/render.sh` rendered all three Cilium-patched machine configs into
  ignored `generated/`; the pinned Talos strict metal validator accepted all
  three files.
- `kubectl kustomize infrastructure/controllers/cilium` built a 122-line
  manifest. The generated source, HelmRelease, ConfigMap and values data
  parsed successfully with the local Ruby YAML parser.
- Helm pulled chart `1.18.13` at OCI manifest digest
  `sha256:876b611ff5c63b79d5e8e2621bdbad237ec9089cde72da333df61ff27b55fc81`;
  `helm lint` reported `1 chart(s) linted, 0 chart(s) failed`, and local
  `helm template` produced the rendered chart.
- Rendered chart settings show Kubernetes IPAM, kube-proxy replacement `false`,
  tunnel/VXLAN routing, `/sys/fs/bpf`, `/sys/fs/cgroup`, two operator replicas
  and the three pinned image digests. A direct search found no `SYS_MODULE`,
  `mount-cgroup` or `mount-bpf-fs` in the rendered output.
- `kubectl apply --dry-run=client` was not used as evidence because this
  kubectl attempted live API discovery/current-object reads despite the client
  flag and failed TLS discovery. No object was applied; Kustomize plus local
  YAML parsing are the offline manifest evidence.

## Verification contract

S07B is successful only when the runbook records:

- three Ready nodes, three healthy Cilium agents and two healthy operators;
- pod-to-pod traffic, pod-to-Service traffic and cluster DNS;
- a LAN NodePort response through the retained kube-proxy path;
- an allow/deny result for a disposable `CiliumNetworkPolicy`;
- Flux source, Kustomization and HelmRelease Ready conditions after adoption;
- no test namespace or imperative Cilium object left outside the intended Helm
  release and Flux declarations.

## References (accessed 2026-09-05)

- Talos Cilium guide: https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium
- Talos v1.12 patching: https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/system-configuration/patching
- Talos v1.12 configuration reference: https://docs.siderolabs.com/talos/v1.12/reference/configuration/v1alpha1/config
- Cilium Helm installation: https://docs.cilium.io/en/stable/installation/k8s-install-helm/
- Cilium Helm values: https://docs.cilium.io/en/stable/helm-reference/
- Cilium system requirements: https://docs.cilium.io/en/stable/operations/system_requirements/
- Cilium v1.18.13 release and image digests: https://github.com/cilium/cilium/releases/tag/v1.18.13
- Cilium v1.18.13 OCI chart metadata: https://helm.cilium.io/index.yaml
- Flux HelmRelease: https://fluxcd.io/flux/components/helm/helmreleases/
- Flux Helm API: https://fluxcd.io/flux/components/helm/api/v2/
- Flux Helm adoption: https://fluxcd.io/flux/migration/helm-operator-migration/
- Flux HelmRepository/OCI source types: https://fluxcd.io/flux/components/source/helmrepositories/
- Flux Kustomization dependencies and pruning: https://fluxcd.io/flux/components/kustomize/kustomizations/
- Flux Git bootstrap: https://fluxcd.io/flux/installation/bootstrap/generic-git-server/
- Kubernetes v1.35 network plugins: https://v1-35.docs.kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/

The exact physical procedure, destructive checkpoints and rollback commands are
in [S07B_CILIUM_RUNBOOK.md](S07B_CILIUM_RUNBOOK.md).
