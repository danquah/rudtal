# Rudtal status

This is the shared handoff file for Codex, Claude Code and the human operator.
Update it at the end of every working session. Keep it factual and do not put
credentials, private keys, tokens, rendered machine configurations or kubeconfigs
here.

## Current checkpoint

The N100 control-plane node runs the reviewed S02 configuration from its
internal SSD and now hosts the single-node Kubernetes cluster. Etcd was
bootstrapped exactly once in S03. Kubernetes reports `rudtal-cp-1` Ready,
the control plane is schedulable, and all current `kube-system` pods are
`1/1 Running`.

- Date recorded: 2026-09-05
- Current session: `S03` bootstrap and verify the single-node cluster, complete
- Active physical node: `rudtal-cp-1`
- Kubernetes and Talos address: `192.168.1.121`
- Reserved address: `192.168.1.121` for MAC `e0:51:d8:12:d2:66`
- Reboot state: installation reboot completed; authenticated Talos v1.12.12 API
  responds with RBAC enabled; node boots from `/dev/nvme0n1`
- Boot media: installer USB removed; macOS reported no external physical disk,
  and Talos reported only the internal SSD plus an empty `sr0` Virtual Media device
- Internal target: `/dev/nvme0n1`, AirDisk 256 GB; erasure explicitly approved
- Hardware observed: Intel N100, 4 cores, 16 GB RAM, wired interface `enp3s0`
- Talos config applied: yes, to `rudtal-cp-1` only
- Etcd bootstrapped: yes, exactly once in S03
- Kubernetes cluster running: yes; Kubernetes `v1.35.8`, Flannel CNI
- Control-plane scheduling: enabled; no taints or unschedulable flag observed
- S03 workload: `default/s03-smoke`, `busybox:1.36.1`, `Running` on
  `rudtal-cp-1`, pod IP `10.244.0.4`
- S03 kubeconfig: `state/kubeconfig` (ignored, mode `0600`; contents never committed)

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

## Next action

Start the discovery half of `S04A`: connect JetKVM to the first N150, boot the
Talos installer, note its temporary maintenance address, and inventory its wired
MAC, RAM, firmware and exact install disk. Reserve `192.168.1.122` for the observed
MAC, reboot and verify the reservation, then stop before rendering or applying any
worker configuration. Do not touch `rudtal-worker-2` or Tailscale.

## Known decisions

- Topology: one schedulable N100 control plane and two N150 workers.
- Initial API endpoint: `https://192.168.1.121:6443`.
- Initial networking: router DHCP reservations plus Talos DHCP, Flannel CNI.
- Initial storage: disposable node-local storage.
- Secret plan: private Git repository with SOPS-encrypted Talos secrets; dedicated
  age private identity outside Git and backed up in a password manager.
- Tailscale and Cluster API are later sessions, after the basic cluster and one
  rebuild are understood.

## Open items

- Inventory both N150 nodes and approve their exact install disks.
- Confirm reservations for `192.168.1.122` and `192.168.1.123`.
- Confirm LAN CIDR, gateway, DHCP pool, DNS and NTP.
- Record JetKVM authentication, firmware and Tailscale state.

## Session log

| Session | State | Result |
|---|---|---|
| `S00` | Complete | Media verified; N100 and reserved `.121` address verified in maintenance mode |
| `S01` | Complete | Age recovery copy confirmed; encrypted Talos inputs, patches, render/validate scripts, and clean local control-plane validation |
| `S02` | Complete | N100 installed on `nvme0n1`; authenticated Talos v1.12.12 API verified |
| `S03` | Complete | Etcd bootstrapped once; kubeconfig retrieved to ignored state; single-node Kubernetes healthy; disposable smoke pod running |
| `S04A` | Not started | Inventory and install worker 1 |
| `S04B` | Not started | Inventory and install worker 2 |
| `S05` | Not started | Baseline workload and failure exercise |
| `S06` | Not started | Tailscale operator and access controls |
| `S07` | Not started | Full teardown and reproducible rebuild |
| `S08` | Deferred | Virtualization and Cluster API experiment |

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
