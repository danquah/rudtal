# Rudtal status

This is the shared handoff file for Codex, Claude Code and the human operator.
Update it at the end of every working session. Keep it factual and do not put
credentials, private keys, tokens, rendered machine configurations or kubeconfigs
here.

## Current checkpoint

The N100 control-plane node runs the reviewed S02 configuration from its
internal SSD and hosts the Kubernetes cluster. Etcd was bootstrapped exactly
once in S03. Kubernetes reports both `rudtal-cp-1` and `rudtal-worker-1` Ready.

The installation half of S04A is complete for `rudtal-worker-1`. The N150 was
installed from the reviewed worker configuration onto its approved internal
NVMe. The operator removed the physical installer USB and unmounted JetKVM
virtual CD/DVD media after the reboot.

- Date recorded: 2026-09-05
- Current session: `S04A`, installation complete
- Active physical node: `rudtal-worker-1`
- Control-plane and Kubernetes address: `192.168.1.121`
- Worker address: `192.168.1.122`
- Worker reserved address: `192.168.1.122` for MAC `e0:51:d8:1a:80:37`
- Worker boot state: installed Talos system booted from the internal NVMe
- Worker boot media: physical USB removed; JetKVM virtual CD/DVD unmounted
- Worker internal target: `/dev/nvme0n1`, TWSC TSC3AN512E6-F2T60S, 512 GB; wipe approved and completed
- Worker hardware observed: Intel N150, 4 cores, 16 GB RAM, wired interface `enp3s0`
- Worker firmware: Talos SMBIOS data reported `Default string`; firmware version unavailable
- Talos config applied: yes to `rudtal-cp-1` and `rudtal-worker-1`
- Worker Talos verification: v1.12.12, RBAC enabled, system disk `nvme0n1`, kubelet `Running`/`OK`
- Etcd bootstrapped: yes, exactly once in S03
- Kubernetes cluster running: yes; Kubernetes `v1.35.8`, Flannel CNI
- Control-plane scheduling: enabled; no taints or unschedulable flag observed
- S03 workload: `default/s03-smoke`, `busybox:1.36.1`, `Running` on
  `rudtal-cp-1`, pod IP `10.244.0.4`
- S03 kubeconfig: `state/kubeconfig` (ignored, mode `0600`; contents never committed)
- Kubernetes worker verification: `rudtal-worker-1` `Ready`, internal IP
  `192.168.1.122`, Kubernetes `v1.35.8`, Talos `v1.12.12`

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
  rebuild procedure in S07 if the single-node cluster must be recreated.

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

## Next action

Begin S04B in a separate session to inventory and install `rudtal-worker-2`.
Do not touch worker 2 or Tailscale as part of this completed S04A handoff.

## Known decisions

- Topology: one schedulable N100 control plane and two N150 workers.
- Initial API endpoint: `https://192.168.1.121:6443`.
- Initial networking: router DHCP reservations plus Talos DHCP, Flannel CNI.
- Initial storage: disposable node-local storage.
- Secret plan: private Git repository with SOPS-encrypted Talos secrets; dedicated
  age private identity outside Git and backed up in a password manager.
- Tailscale and Cluster API are later sessions, after the basic cluster and one
  rebuild are understood.
- Final recovery session: S09 will store the SOPS age identity in 1Password and
  prove decryption and configuration rendering from a second trusted machine.

## Open items

- Inventory and approve the install disk for `rudtal-worker-2`.
- Confirm the reservation for `192.168.1.123`.
- Confirm LAN CIDR, gateway, DHCP pool, DNS and NTP.
- Record JetKVM authentication, firmware and Tailscale state.
- Complete the final 1Password cross-machine recovery drill in S09.

## Session log

| Session | State | Result |
|---|---|---|
| `S00` | Complete | Media verified; N100 and reserved `.121` address verified in maintenance mode |
| `S01` | Complete | Age recovery copy confirmed; encrypted Talos inputs, patches, render/validate scripts, and clean local control-plane validation |
| `S02` | Complete | N100 installed on `nvme0n1`; authenticated Talos v1.12.12 API verified |
| `S03` | Complete | Etcd bootstrapped once; kubeconfig retrieved to ignored state; single-node Kubernetes healthy; disposable smoke pod running |
| `S04A` | Complete | Installed `rudtal-worker-1` on its approved 512 GB NVMe; removed boot media; verified authenticated Talos and Kubernetes `Ready` |
| `S04B` | Not started | Inventory and install worker 2 |
| `S05` | Not started | Baseline workload and failure exercise |
| `S06` | Not started | Tailscale operator and access controls |
| `S07` | Not started | Full teardown and reproducible rebuild |
| `S08` | Deferred | Virtualization and Cluster API experiment |
| `S09` | Not started | 1Password-backed SOPS recovery from a second machine |

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

The globally installed `talosctl` is v1.11.1. Use the exact v1.12.12 binary above
until a later session deliberately changes the tool setup.
