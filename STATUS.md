# Rudtal status

This is the shared handoff file for Codex, Claude Code and the human operator.
Update it at the end of every working session. Keep it factual and do not put
credentials, private keys, tokens, rendered machine configurations or kubeconfigs
here.

## Current checkpoint

The N100 control-plane node has been installed from the reviewed S02 configuration
and answers the authenticated Talos API at `192.168.1.121`. Talos reports
`nvme0n1` as its system disk. Etcd has not been bootstrapped, so the node remains
in the expected pre-bootstrap `booting` stage.

- Date recorded: 2026-09-05
- Current session: `S02` render, review and install the control plane, complete
- Active physical node: proposed `rudtal-cp-1`
- Current maintenance address: `192.168.1.121`
- Earlier discovery address: `192.168.1.12`
- Reserved address: `192.168.1.121` for MAC `e0:51:d8:12:d2:66`
- Reboot state: installation reboot completed; authenticated Talos v1.12.12 API
  responds with RBAC enabled
- Boot media: physical USB prepared and successfully reached the Talos v1.12.12
  boot menu
- Internal target: `/dev/nvme0n1`, AirDisk 256 GB; erasure explicitly approved
- Hardware observed: Intel N100, 4 cores, 16 GB RAM, wired interface `enp3s0`
- Talos config applied: yes, to `rudtal-cp-1` only
- etcd bootstrapped: no
- Kubernetes cluster running: no

## Local tooling

- Exact Talos client: `downloads/talosctl-v1.12.12-darwin-arm64`
- Exact client SHA-256 verified: yes
- Talos ISO: `downloads/metal-amd64-v1.12.12.iso`
- ISO SHA-256 verified: yes; see `INSTALL_MEDIA.md`
- SOPS: 3.13.3 installed
- age: 1.3.2 installed
- age directory: `~/.config/sops/age/` exists
- dedicated age identity: generated at `~/.config/sops/age/rudtal.txt`, mode 0600; recovery copy confirmed in the password manager
- Initial local render was discarded; the Talos secrets bundle was rotated before final validation, and no rendered or plaintext secret file is retained in Git.
- Git: initialized on `main`; S01 pipeline committed

The globally installed `talosctl` is v1.11.1. Use the exact v1.12.12 binary above
until a later session deliberately changes the tool setup.

## Next action

Start `S03`: verify the installer USB is removed, perform the one-time etcd
bootstrap against `192.168.1.121`, retrieve a kubeconfig into ignored local state,
and wait for the Kubernetes node and system pods. Do not add workers or Tailscale
in S03.

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
| `S03` | Not started | Bootstrap and verify the single-node cluster |
| `S04A` | Not started | Inventory and install worker 1 |
| `S04B` | Not started | Inventory and install worker 2 |
| `S05` | Not started | Baseline workload and failure exercise |
| `S06` | Not started | Tailscale operator and access controls |
| `S07` | Not started | Full teardown and reproducible rebuild |
| `S08` | Deferred | Virtualization and Cluster API experiment |
