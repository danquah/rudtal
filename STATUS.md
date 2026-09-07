# Rudtal status

This is the shared handoff file for Codex, Claude Code and the human operator.
Update it at the end of every working session. Keep it factual and do not put
credentials, private keys, tokens, rendered machine configurations or kubeconfigs
here.

## Current checkpoint

The fresh S07B cluster generation is installed on the approved internal NVMe
disks, uses Cilium `1.20.1` as its CNI, and has a sole control plane plus two
workers. Etcd was bootstrapped exactly once for this fresh generation. Flux
reconciles the promoted `main` source; the former Flannel baseline and
experiment branch have been retired.

The installation half of S04A is complete for `rudtal-worker-1`. The N150 was
installed from the reviewed worker configuration onto its approved internal
NVMe. The operator removed the physical installer USB and unmounted JetKVM
virtual CD/DVD media after the reboot.

S04B installation and verification are complete for `rudtal-worker-2` at
`192.168.1.123`. The router reservation for MAC `e0:51:d8:1a:83:85` was
verified before apply; the approved internal NVMe was wiped and Talos installed.
The operator removed the physical installer USB after reboot and left JetKVM
virtual media unmounted. S05 changed no configuration, storage, boot media, or
Tailscale state at that time.

- Date recorded: 2026-09-07
- Current session: `S08C` G0 complete — a credential-free, unpromoted
  ProxyClass and two-replica auth-mode ProxyGroup candidate are committed only
  on `experiment/tailscale-proxygroup-s08c`. The existing in-process
  `apiServerProxyConfig.mode: "true"` remains the live routine endpoint.
- G0 performed no Tailscale account, credential, cluster, Flux, Talos, Cilium,
  node, router, JetKVM, or public-exposure mutation. The candidate reuses only
  the existing `tailscale/operator-oauth` reference and does not render Secret
  data.
- Read-only baseline verification found all three nodes Ready; Cilium `3/3`,
  CoreDNS `2/2`, the Tailscale Operator `1/1`, all six Flux Kustomizations, and
  both HelmReleases Ready at observed `main@sha1:8ee5a834`. The retained
  in-process endpoint returned `/readyz`; its routine checks remained `yes` for
  `list nodes` and `no` for `get secrets --all-namespaces`.
- The local candidate pins `tailscale/k8s-proxy:v1.102.3` to Docker Hub index
  `sha256:82de09cb7b97b7e59201c21af2d4a189d688e448948b092c2e020b3ccd9d4546`,
  requires cross-node anti-affinity, and proposes only the additive canary tag,
  exact-service auto-approver, dual-port grant, and existing reader-group
  impersonation capability. G1 requires human policy-editor review, tests, and
  explicit promotion/automatic-rollback authorization.
- Fresh cluster generation: `rudtal-cp-1`, `rudtal-worker-1`, and
  `rudtal-worker-2` are `Ready` on Talos `v1.12.12` and Kubernetes `v1.35.8`.
- Hardware identity before the destructive boundary and again in maintenance
  mode matched the approved wired MACs and internal NVMe disks: the 256 GB
  AirDisk `nvme0n1` control plane and both 512 GB TWSC `nvme0n1` workers.
- The corrected singleton control-plane
  `reset --graceful=false --system-labels-to-wipe EPHEMERAL
  --system-labels-to-wipe STATE --reboot` completed; workers were not reset a
  second time. Fresh reviewed Talos configs applied successfully.
- Etcd was bootstrapped exactly once at `192.168.1.121`. Before Cilium, only
  etcd, apid, and Kubernetes `/readyz` were checked; all nodes were then
  expectedly restored to Ready by Cilium.
- Cilium `1.20.1` is Helm release `kube-system/cilium` revision 2, adopted by
  a Ready Flux HelmRelease from the pinned OCI manifest
  `sha256:906ce40d35daad838d12add8a5ba7033e767767f51799a93c7eace2cec9cdc05`.
  Three Cilium agents, three Envoy Pods, two operators, CoreDNS, and retained
  kube-proxy were Running; full authenticated Talos health passed.
- Flux source, all five Kustomizations, the Cilium OCIRepository, and the
  Cilium HelmRelease are Ready at observed `main@sha1:f07fd5e7`.
- Cross-worker Pod-IP and ClusterIP traffic, cluster DNS, and NodePort `30600`
  through all three LAN node addresses passed. The namespaced policy allowed
  the selected client and timed out the blocked client; `s07-nettest` was
  deleted afterward.
- `main` was promoted and the source handoff commit was applied to both
  branches before Flux changed to `main`. The remote and local
  `experiment/cilium-s07` branch are deleted.
- The temporary write-capable bootstrap deploy key was retired only after the
  replacement read-only deploy key fetched `main` and stayed Ready through a
  source interval. The cluster-only Flux Secret was never displayed.
- Rendered Talos outputs, temporary Cosign/chart files, test manifests, and
  both local deploy-key pairs were removed. `state/kubeconfig` remains ignored
  for routine local administration and was not displayed.
- S08 final observation: all three nodes remained Ready; three Cilium agents
  and CoreDNS `2/2` were Running; all six Flux Kustomizations and both
  HelmReleases were Ready at `main@sha1:2bcd6216`. Kubernetes declares only
  ClusterIP Services, no Ingress, and no NodePort. This does not audit router
  WAN forwarding.
- The user set a JetKVM local password. JetKVM app `0.5.8` and system `0.2.8`
  remain outside the tailnet; no router, Talos machine configuration, subnet
  route, exit node, or public Kubernetes exposure was changed by S08.
- S05 baseline before workload: Talos `get cpustats` cumulative user/system and
  `get memorystats` used/total (reported KiB) were `rudtal-cp-1` `178/528.83`,
  `1,928,672/16,057,704`; `rudtal-worker-1` `79.53/70.97`,
  `1,053,124/16,050,560`; and `rudtal-worker-2` `27.55/25.53`,
  `1,055,960/16,050,560`. Each node reported 4 CPUs and about 16 GiB capacity.
- Kubernetes Metrics API was unavailable, so no instantaneous CPU percentage or
  `kubectl top` result is claimed; the recorded CPU values are cumulative
  counters.
- S03 workload: deleted during S05 cleanup; no default application workload
  remains
- S03 kubeconfig: `state/kubeconfig` (ignored, mode `0600`; contents never committed)
- Kubernetes worker verification: `rudtal-worker-1` `Ready`, internal IP
  `192.168.1.122`, Kubernetes `v1.35.8`, Talos `v1.12.12`
- Final worker Talos verification: server v1.12.12, RBAC enabled, system disk
  `nvme0n1`, and kubelet `Running`/`OK`
- Final Kubernetes verification: `rudtal-worker-2` `Ready`, internal IP
  `192.168.1.123`, Kubernetes `v1.35.8`, Talos `v1.12.12`
- Final worker maintenance address: `192.168.1.123`
- Final worker wired MAC: `e0:51:d8:1a:83:85` on `enp3s0`
- Final worker hardware: Intel N150, 4 cores / 4 threads, 16,384 MiB RAM
- Final worker install disk: `/dev/nvme0n1`, TWSC TSC3AN512E6-F2T60S,
  512 GB, serial `TTSMA253SX01711`; wipe approved and completed
- Final worker boot media: physical SanDisk USB removed after reboot; JetKVM
  `sr0` was empty and virtual media was unmounted

## S03 record

- Pre-bootstrap check: Talos `etcd` was `Preparing` in `Running pre state`.
- Bootstrap command: pinned `downloads/talosctl-v1.12.12-darwin-arm64 bootstrap`
  against `192.168.1.121`; command exited successfully once.
- Health checks: Talos health passed etcd, apid, kubelet, diagnostics, static
  control-plane pods, kube-proxy, CoreDNS, node readiness and schedulability;
  Kubernetes `/readyz?verbose` passed; all observed system pods were `1/1 Running`.
- Workload command: `kubectl run s03-smoke --image=busybox:1.36.1
  --restart=Never --command -- sh -c 'printf "rudtal-s03-smoke\n"; sleep 3600'`.
  The pod emitted `rudtal-s03-smoke` and remained `Running`.
- Kubernetes emitted a `restricted:latest` PodSecurity warning for this ad-hoc
  pod; the warning did not block scheduling or execution.
- Workload cleanup/recovery: `KUBECONFIG=state/kubeconfig kubectl delete pod
  s03-smoke --ignore-not-found`; server dry-run was verified without deleting it.
- Recovery boundary: do not rerun bootstrap; use the deliberate Talos reset and
  rebuild procedure in S09 if the single-node cluster must be recreated.

## S04A discovery record

- Target: `rudtal-worker-1`, GMKtec NucBox G3 Plus
- Talos maintenance API: v1.12.12
- Address observation: `192.168.1.122/24` on `enp3s0`; no separate pre-reservation lease was captured
- Wired MAC: `e0:51:d8:1a:80:37`
- CPU and memory: Intel N150, 4 cores / 4 threads, 16,384 MiB
- Storage: internal NVMe `/dev/nvme0n1` (`TWSC TSC3AN512E6-F2T60S`, 512 GB); `/dev/sda` was the 123 GB SanDisk USB; `/dev/sr0` was JetKVM Virtual Media
- Firmware: system information exposed `Default string`; no firmware version was available through maintenance mode
- DHCP reservation: `192.168.1.122` for the observed MAC, verified after reboot

## S04A installation record

- The operator explicitly approved erasing `/dev/nvme0n1` before rendering or applying the worker configuration.
- Render command: `INSTALL_DISK=/dev/nvme0n1 ./scripts/render.sh worker rudtal-worker-1`.
- Strict Talos metal validation passed for `generated/rudtal-worker-1/worker.yaml`.
- Final pre-apply check matched `192.168.1.122`, MAC `e0:51:d8:1a:80:37`, and the 512 GB TWSC `nvme0n1`; USB and JetKVM media were distinct.
- Pinned `talosctl-v1.12.12` `apply-config --insecure` completed without error and installed Talos to the approved NVMe.
- After reboot, the operator removed the physical USB and unmounted JetKVM virtual CD/DVD media.
- Authenticated Talos verification passed: server v1.12.12 with RBAC enabled, system disk `nvme0n1`, and kubelet `Running`/`OK`.
- Kubernetes verification passed: `rudtal-worker-1` registered at `192.168.1.122` and became `Ready` on v1.35.8.

## S04B installation record

- The operator explicitly approved erasing the final worker's `/dev/nvme0n1`
  (TWSC TSC3AN512E6-F2T60S, 512 GB) before rendering or applying the worker
  configuration.
- Render command: `INSTALL_DISK=/dev/nvme0n1 ./scripts/render.sh worker rudtal-worker-2`.
- Strict Talos metal validation passed for
  `generated/rudtal-worker-2/worker.yaml`.
- Final pre-apply discovery matched `192.168.1.123`, MAC
  `e0:51:d8:1a:83:85`, and the writable 512 GB TWSC NVMe; `/dev/sda` was the
  distinct physical USB and `sr0` was empty read-only JetKVM media.
- Pinned `talosctl-v1.12.12 apply-config --insecure` completed without error
  and installed Talos to the approved NVMe.
- After reboot, the operator removed the physical USB and left JetKVM virtual
  media unmounted.
- Authenticated Talos verification passed: server v1.12.12 with RBAC enabled,
  system disk `nvme0n1`, and kubelet `Running`/`OK`.
- Kubernetes verification passed: `rudtal-worker-2` registered at
  `192.168.1.123` and became `Ready` on v1.35.8.

## S05 record

- Baseline node health: all three nodes were `Ready`, schedulable, and on
  Kubernetes `v1.35.8` / Talos `v1.12.12`; authenticated Talos services were
  healthy, including `etcd` only on `rudtal-cp-1`.
- Disposable workload: `default/s05-web`, three `nginx:1.27-alpine` replicas,
  exposed as `default/s05-web-lan` NodePort `30368/TCP`. Before the failure,
  one replica ran on each node and all three LAN node addresses returned HTTP
  `200`.
- At `2026-09-05T19:20:04Z`, with the operator watching the console, the
  authenticated pinned Talos client requested a graceful reboot of only
  `192.168.1.121` using `--mode default --wait --timeout=90s`. The reboot
  stopped the control-plane Talos services and the local workload pod without
  erasing the internal SSD or changing configuration.
- At `2026-09-05T19:21:28Z`, `rudtal-cp-1` was `NotReady` while both workers
  remained `Ready`; the worker NodePorts returned HTTP `200`, while the
  control-plane NodePort refused the connection. Kubernetes `/readyz` was
  already `ok` at that sample, so an exact Kubernetes API outage duration was
  not measured; Talos reboot progress did show its API unavailable during
  teardown/boot.
- After recovery, Talos `health` passed etcd consistency, API readiness,
  kubelet, static control-plane pods, kube-proxy, CoreDNS, node readiness and
  schedulability. The Deployment controller created a replacement on
  `rudtal-worker-1`; the workload reached `3/3` and its EndpointSlice again had
  three worker-backed endpoints.
- The disposable Deployment, Service and the old `s03-smoke` pod were deleted
  after observation. No Tailscale configuration was added or changed.

## S06 record

- The operator completed GitHub bootstrap for
  `git@github.com:danquah/rudtal.git` on `main`. Bootstrap-generated
  non-secret files were fast-forwarded locally at revision `0c72f74`.
- Flux `v2.9.5` is bootstrapped with source-controller `v1.9.5`,
  kustomize-controller `v1.9.5`, helm-controller `v1.6.4` and
  notification-controller `v1.9.4`. All four controller pods and Flux CRDs
  verified healthy.
- The cluster sync graph is `flux-system` → `infra-controllers` →
  `infra-configs` → `apps`, with `dependsOn`, `wait: true`, `prune: true`,
  ten-minute intervals and two-minute retry intervals. Repository declarations
  live under `clusters/rudtal/`, `infrastructure/` and `apps/rudtal/`.
- A harmless ConfigMap was committed as `f00d747`, reconciled from Git, changed
  imperatively to prove drift correction, restored to its Git value, then
  removed in cleanup commit `9f8ec96`. Flux pruned it; the final default
  namespace contains no S06 application object.
- The SOPS policy scopes future Kubernetes `*.sops.yaml` files to
  `data`/`stringData`. No real Kubernetes Secret or Flux SOPS decryption key
  was created; the Talos age identity remains outside the cluster.
- Final checks: Flux `check`, source and Kustomization status, all three
  Kubernetes nodes, Flannel, and system pods passed. No Cilium or Tailscale
  configuration was added.

## S07A record

- Scope: high-reasoning correction and offline validation only. No Talos node,
  disk, machine configuration, etcd state, Kubernetes object, Flux
  reconciliation, Git remote, deploy key or credential was changed.
- The user reports the live Flannel cluster is healthy and Flux watches `main`;
  S07A did not reconfigure it.
- The reviewed correction is on `experiment/cilium-s07`, based on its original
  `1d6a21b` preparation commit. Before P1, the operator verified local and
  remote `main` at `a6233e4` and local and remote `experiment/cilium-s07` at
  `b97fead`; the experiment contains the main baseline. No history was rewritten.
- Cilium `1.18.13` was rejected because a Helm `kubeVersion` range is not
  tested-compatibility proof. The reviewed pin is Cilium `1.20.1`, whose
  current upstream compatibility matrix explicitly lists Kubernetes `1.35` as
  e2e-tested. Talos remains `v1.12.12`; kube-proxy remains enabled.
- The OCI manifest is
  `sha256:906ce40d35daad838d12add8a5ba7033e767767f51799a93c7eace2cec9cdc05`;
  values pin the selected agent, generic operator and Envoy image digests.
  Helm 3.19.0 pulled, linted and rendered the chart; the rendered manifest
  contained all three pinned image digests and no `SYS_MODULE`, `mount-cgroup`
  or `mount-bpf-fs`.
- A temporary Cosign v3.1.3 executable matched its upstream SHA-256. The
  documented Cilium identity/issuer verification then exited successfully:
  Cosign validated the claims and trusted signing certificate, verified
  transparency-log inclusion offline, and returned the exact pinned OCI
  manifest digest. No cluster connection was made.
- Shell syntax/ShellCheck, Cilium and controller Kustomize builds, Markdown
  links/fences, and all three freshly rendered Cilium-patched strict Talos
  metal validations passed. Generated configs remain ignored and were not
  displayed.
- The revised S07B sequence uses authenticated installed-node identity checks,
  worker-first reset, maintenance-mode rechecks, no-CNI API/etcd-only checks,
  immediate Cilium installation with explicit kubeconfig, then full health.
  It documents Helm/Flux ownership verification, cross-node policy traffic,
  safe branch promotion and deploy-key rotation.
- The future portable administration work is split into S10A implementation and
  S10B clean-machine proof. Its design separates routine Tailscale/Kubernetes
  RBAC, scoped Talos clients and full 1Password/SOPS break-glass recovery.

S07B remains gated on review/approval of the final corrected experiment commit,
acceptance of the destructive reset/reinstall and the recorded Flannel rollback.
P1 repeated the digest-bound Cosign verification, confirmed declared workload
and storage disposability, and matched endpoint/MAC/system disk; it does not
authorize a destructive action.

## S07B P1 record

- Scope: read-only live Kubernetes and authenticated Talos discovery plus local
  artifact/configuration verification. No node was reset, rebooted, reconfigured
  or applied; etcd, Kubernetes objects, Flux, Git remotes and credentials were
  not changed.
- Baseline: `rudtal-cp-1`, `rudtal-worker-1` and `rudtal-worker-2` were Ready
  at `192.168.1.121`, `.122` and `.123`, on Talos `v1.12.12` and Kubernetes
  `v1.35.8`. Three Flannel and three kube-proxy Pods were `1/1 Running`;
  CoreDNS and all four Flux controllers were healthy. The Flux Git source and
  all four Kustomizations were Ready at `main@sha1:a6233e47`; Cilium was absent.
- Disposability evidence: only system and Flux controller workloads were
  present. PVCs, PVs, StorageClasses, VolumeAttachments and Cilium Pods were
  absent. There is no Kubernetes-declared persistent volume or attachment to
  preserve.
- Artifact evidence: Helm `v3.19.0` pulled the Cilium `1.20.1` chart at the
  pinned manifest `sha256:906ce40d35daad838d12add8a5ba7033e767767f51799a93c7eace2cec9cdc05`;
  the archive matched layer SHA-256
  `06210eef7c23d15f7699c79e2fe3a1ec9c389024c5c5c006ea04022d322449a2`.
  Helm lint and template passed. A temporary official-checksum-verified Cosign
  `v3.1.3` binary verified the exact manifest against the Cilium GitHub identity
  regexp and GitHub Actions issuer, including offline transparency-log evidence.
- Configuration evidence: the Cilium no-CNI patch rendered with all three node
  inputs; each resulting config passed pinned Talos strict metal validation
  without its contents being displayed.
- Identity evidence: authenticated Talos reads matched every reserved endpoint,
  wired `enp3s0` MAC and `nvme0n1` system disk in `INVENTORY.md`: 256 GB AirDisk
  on the control plane and 512 GB TWSC TSC3AN512E6-F2T60S on both workers.
  `rudtal-worker-2` separately exposed a read-only, empty `sr0` virtual-media
  device; it was not the system disk.
- Cleanup: the generated configs/talosconfig and temporary chart/Cosign workspace
  were removed. No credential-bearing rendered output was retained.
- P1 evidence gates passed, but S07B is not approved. The destructive reset,
  rebuild, etcd bootstrap, Helm installation, Flux bootstrap and Git changes
  remain unperformed and require a reviewed P1 handoff plus explicit approval.
- Orchestrator review independently reconfirmed three Ready nodes, only system
  and Flux workloads, no PVC/PV/StorageClass/VolumeAttachment or Cilium Pod,
  and the Flux source plus all Kustomizations Ready at `main@sha1:a6233e47`.
  The P1 handoff was accepted; the operator then authorized and began P2 with
  JetKVM present.

## S07B P2 halt record

- Fresh Cilium no-CNI configs for all three named nodes were rendered and each
  passed pinned `talosctl validate --mode metal --strict`; the credential-bearing
  output was removed after the halt.
- Immediately before each reset, authenticated Talos reads matched every
  reserved endpoint, wired `enp3s0` MAC, and system disk in `INVENTORY.md`.
- The worker-1 and worker-2 commands completed their graceful drain, cleanup,
  `EPHEMERAL`/`STATE` wipe, reboot, and insecure maintenance identity checks.
  In Talos v1.12.12, `version --insecure` is unimplemented in maintenance
  mode; successful insecure `get links` and `get disks` established that mode.
- The exact non-secret control-plane command was
  `downloads/talosctl-v1.12.12-darwin-arm64 --talosconfig generated/rudtal-cp-1/talosconfig --nodes 192.168.1.121 reset --graceful --system-labels-to-wipe EPHEMERAL --system-labels-to-wipe STATE --reboot`.
  It stopped at `leaveEtcd`: `etcdserver: re-configuration failed due to not
  enough started members`.
- The subsequent authenticated response from `.121` reported Talos v1.12.12
  with RBAC and `etcd` `Running`/`OK`; this is unexpected persistent state for
  the intended reset. The checkpoint is failed and S07B is halted. No
  configuration apply, bootstrap, Cilium, Flux, test, credential, or Git
  operation followed.
- State at halt: the operator requested review of a singleton-control-plane
  reset/rebuild procedure rather than retrying or altering the CNI in place.
- Review result: the observed failure is the documented behavior for a
  single-member etcd cluster. The old control plane remains healthy and is the
  only etcd member; both workers remain in maintenance mode. The corrected
  continuation resets only the control plane with `--graceful=false`, then
  applies fresh reviewed configs to all three nodes and bootstraps the new etcd
  generation exactly once.

## S07B P2 completion record

- The singleton control-plane recovery used the reviewed
  `--graceful=false` reset. Its completed reset sequence reached maintenance
  mode with the matched AirDisk NVMe; no worker reset was repeated.
- Fresh Cilium no-CNI configs for all three nodes passed strict metal
  validation and applied successfully. The new control plane bootstrapped etcd
  once; authenticated etcd/APId checks and Kubernetes `/readyz` passed before
  Cilium installation.
- Helm v3.19.0 pulled the exact Cilium `1.20.1` manifest and archive layer.
  A temporary Cosign v3.1.3 Darwin arm64 binary matched its official SHA-256,
  then verified the Cilium GitHub identity, GitHub Actions issuer, trusted
  certificate, and offline transparency-log inclusion for that manifest.
- Imperative Helm installation created `kube-system/cilium` revision 1. Flux
  adopted it with successful Helm upgrade revision 2; the OCIRepository,
  HelmRelease, all Flux Kustomizations, Cilium DaemonSet, nodes, and full
  Talos health remained Ready.
- The disposable cross-node test placed server and clients on the required
  distinct workers. Direct Pod IP, ClusterIP, DNS, and three-node NodePort
  paths passed; the CiliumNetworkPolicy allowed only the labelled client and
  blocked the other client by timeout. Namespace deletion completed.
- After a ten-minute stable reconciliation interval, `main` was promoted and
  Flux changed from `experiment/cilium-s07` to `main@sha1:f07fd5e7`. The
  replacement read-only deploy key fetched that revision and remained Ready
  through another source interval before the old write key and experiment
  branch were removed.





S08C G0 is complete locally. The working in-process Tailscale API proxy remains
the live routine endpoint. A human operator must complete G1 in the Tailscale
policy editor: merge the additive fragment without removing existing rules; run
its policy tests; verify tag ownership, exact
`svc:rudtal-k8s-api-canary` auto-approval, TCP `80`/`443`, the unchanged reader
impersonation group, and retained in-process access; then explicitly authorize
promotion of the reviewed commit and automatic Git/Flux rollback on canary
failure. Until then do not push, merge, deploy, change the Tailscale account or
credential, alter Talos/Cilium/nodes/router/JetKVM, expose a public port, or edit
generated Secrets.

## Known decisions

- Topology: one schedulable N100 control plane and two N150 workers.
- Initial API endpoint: `https://192.168.1.121:6443`.
- Current networking: router DHCP reservations plus Talos DHCP and Cilium
  `1.20.1`; Talos-managed kube-proxy remains enabled.
- Initial storage: disposable node-local storage.
- Secret plan: private Git repository with SOPS-encrypted Talos secrets; dedicated
  age private identity outside Git and backed up in a password manager.
- GitOps is introduced while Flannel is healthy; Cilium is tested in a disposable
  rebuild before Tailscale is added.
- Final recovery sessions: S10A will build portable, pinned administration tools;
  S10B will prove routine access and 1Password-backed break-glass recovery from
  a second trusted machine.
- Repository curation is deferred to S11, after the rebuild and recovery material
  has stabilized; live Talos and Flux paths remain unchanged until then.
- A schedulable three-control-plane/three-member-etcd experiment is deferred
  until after the main plan; `docs/plans/ha-control-plane-experiment.md` records
  the resource measurements, quorum exercise and rollback questions.

## Open items

- Confirm LAN CIDR, gateway, DHCP pool, DNS and NTP.
- Complete portable administration tooling in S10A and the 1Password
  cross-machine recovery drill in S10B.
- Complete the final repository curation and clean-clone handoff in S11.
- Decide whether to run the optional S08C Tailscale API ProxyGroup canary after
  its supervised tailnet-policy gate.
- Revisit the optional three-control-plane experiment after the main plan.

## Session log

| Session | State | Result |
|---|---|---|
| `S00` | Complete | Media verified; N100 and reserved `.121` address verified in maintenance mode |
| `S01` | Complete | Age recovery copy confirmed; encrypted Talos inputs, patches, render/validate scripts, and clean local control-plane validation |
| `S02` | Complete | N100 installed on `nvme0n1`; authenticated Talos v1.12.12 API verified |
| `S03` | Complete | Etcd bootstrapped once; kubeconfig retrieved to ignored state; single-node Kubernetes healthy; disposable smoke pod running |
| `S04A` | Complete | Installed `rudtal-worker-1` on its approved 512 GB NVMe; removed boot media; verified authenticated Talos and Kubernetes `Ready` |
| `S04B` | Complete | Installed `rudtal-worker-2` on its approved 512 GB NVMe; removed boot media; verified authenticated Talos and Kubernetes `Ready` |
| `S05` | Complete | Recorded Talos/Kubernetes baseline; deployed and cleaned up a LAN NodePort workload; rebooted and recovered only the control plane; documented worker continuity and reconciliation |
| `S06` | Complete | Bootstrapped Flux v2.9.5 on GitHub, added the declarative cluster/infrastructure/apps layout, proved reconciliation and drift correction, and pruned the disposable check |
| `S07` | Complete | Rebuilt a fresh Cilium `1.20.1` cluster, proved Flux adoption, cross-node networking/policy paths, main handoff, and read-only credential rotation |
| `S08` | Complete | Tailscale Operator auth proxy deployed through Flux, HTTPS tailnet access and narrow Kubernetes RBAC proven, failed ProxyGroup and orphaned generated state pruned |
| `S08C` | G0 complete | Local, credential-free two-replica ProxyGroup candidate validated and committed; supervised tailnet-policy gate remains before any promotion or deployment |
| `S09` | Not started | Full teardown and reproducible rebuild |
| `S10A` | Not started | Portable pinned tools and separated routine/break-glass administration paths |
| `S10B` | Not started | Tailscale/RBAC and 1Password recovery drill from a clean trusted machine |
| `S11` | Not started | Curate durable documentation, archive project history and validate a clean clone |

## Local tooling

- Exact Talos client: `downloads/talosctl-v1.12.12-darwin-arm64`
- Exact client SHA-256 verified: yes
- Talos ISO: `downloads/metal-amd64-v1.12.12.iso`
- ISO SHA-256 verified: yes; see `INSTALL_MEDIA.md`
- Kubernetes client config: `state/kubeconfig`, ignored and mode `0600`; contents
  are never displayed or committed
- SOPS: 3.13.3 installed
- age: 1.3.2 installed
- age directory: `~/.config/sops/age/` exists
- dedicated age identity: generated at `~/.config/sops/age/rudtal.txt`, mode 0600; recovery copy confirmed in the password manager
- Initial local render was discarded; the Talos secrets bundle was rotated before final validation, and no rendered or plaintext secret file is retained in Git.
- Git: initialized on `main`; S01 pipeline committed
- Flux CLI: `$HOME/bin/flux` v2.9.5 installed after official Darwin arm64 SHA-256 verification; generated Flux manifests are tracked under `clusters/rudtal/flux-system/`

The globally installed `talosctl` is v1.11.1. Use the exact v1.12.12 binary above
until a later session deliberately changes the tool setup.
