# Rudtal status

This is the shared handoff file for Codex, Claude Code and the human operator.
Update it at the end of every working session. Keep it factual and do not put
credentials, private keys, tokens, rendered machine configurations or kubeconfigs
here.

## Current checkpoint

The N100 control-plane node runs the reviewed S02 configuration from its
internal SSD and hosts the Kubernetes cluster. Etcd was bootstrapped exactly
once in S03. S06 established Flux-based declarative add-on management while
preserving the healthy Flannel baseline; all three nodes and system pods remain
healthy.

The installation half of S04A is complete for `rudtal-worker-1`. The N150 was
installed from the reviewed worker configuration onto its approved internal
NVMe. The operator removed the physical installer USB and unmounted JetKVM
virtual CD/DVD media after the reboot.

S04B installation and verification are complete for `rudtal-worker-2` at
`192.168.1.123`. The router reservation for MAC `e0:51:d8:1a:83:85` was
verified before apply; the approved internal NVMe was wiped and Talos installed.
The operator removed the physical installer USB after reboot and left JetKVM
virtual media unmounted. S05 changed no configuration, storage or boot media;
Tailscale remains untouched.

- Date recorded: 2026-09-05
- Current session: `S06`, Flux GitOps foundation complete
- Active physical node: `rudtal-cp-1` (rebooted and restored)
- Control-plane and Kubernetes address: `192.168.1.121`
- Worker address: `192.168.1.122`
- Worker reserved address: `192.168.1.122` for MAC `e0:51:d8:1a:80:37`
- Worker boot state: installed Talos system booted from the internal NVMe
- Worker boot media: physical USB removed; JetKVM virtual CD/DVD unmounted
- Worker internal target: `/dev/nvme0n1`, TWSC TSC3AN512E6-F2T60S, 512 GB; wipe approved and completed
- Worker hardware observed: Intel N150, 4 cores, 16 GB RAM, wired interface `enp3s0`
- Worker firmware: Talos SMBIOS data reported `Default string`; firmware version unavailable
- Talos config applied: yes to `rudtal-cp-1`, `rudtal-worker-1` and
  `rudtal-worker-2`
- Worker Talos verification: v1.12.12, RBAC enabled, system disk `nvme0n1`, kubelet `Running`/`OK`
- Etcd bootstrapped: yes, exactly once in S03
- Kubernetes cluster running: yes; Kubernetes `v1.35.8`, Flannel CNI
- Kubernetes add-ons: Flux `v2.9.5` is bootstrapped and healthy; Cilium and
  Tailscale are not installed.
- Flux source and Kustomizations are Ready at Git revision
  `main@sha1:9f8ec968`; the cluster-only `flux-system` Git credential Secret
  exists but its contents were never displayed.
- Control-plane scheduling: enabled; no taints or unschedulable flag observed
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

## Next action

Begin S07 Cilium disposable rebuild experiment from the healthy Flannel
baseline. Keep the current cluster unchanged until the CNI replacement,
kube-proxy choice and rollback path are reviewed.

## Known decisions

- Topology: one schedulable N100 control plane and two N150 workers.
- Initial API endpoint: `https://192.168.1.121:6443`.
- Initial networking: router DHCP reservations plus Talos DHCP, Flannel CNI.
- Initial storage: disposable node-local storage.
- Secret plan: private Git repository with SOPS-encrypted Talos secrets; dedicated
  age private identity outside Git and backed up in a password manager.
- GitOps is introduced while Flannel is healthy; Cilium is tested in a disposable
  rebuild before Tailscale is added.
- Final recovery session: S10 will store the SOPS age identity in 1Password and
  prove decryption and configuration rendering from a second trusted machine.
- Repository curation is deferred to S11, after the rebuild and recovery material
  has stabilized; live Talos and Flux paths remain unchanged until then.

## Open items

- Confirm LAN CIDR, gateway, DHCP pool, DNS and NTP.
- Record JetKVM authentication, firmware and Tailscale state.
- Complete the final 1Password cross-machine recovery drill in S10.
- Complete the final repository curation and clean-clone handoff in S11.

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
| `S07` | Not started | Cilium disposable rebuild experiment |
| `S08` | Not started | Tailscale operator and access controls |
| `S09` | Not started | Full teardown and reproducible rebuild |
| `S10` | Not started | 1Password-backed SOPS recovery from a second machine |
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
