# Rudtal status

This is the shared handoff file for Codex, Claude Code and the human operator.
Update it at the end of every working session. Keep it factual and do not put
credentials, private keys, tokens, rendered machine configurations or kubeconfigs
here.

## Current checkpoint

The repository now contains the S01 encrypted Talos configuration pipeline:
version pins, SOPS policy, patch inputs, render and validation scripts, and a
fresh SOPS-encrypted Talos secrets bundle. No machine configuration has been
applied and no internal SSD has been erased.

- Date recorded: 2026-09-05
- Current session: `S01` repository and encrypted configuration pipeline, complete
- Active physical node: proposed `rudtal-cp-1`
- Current maintenance address: `192.168.1.121`
- Earlier discovery address: `192.168.1.12`
- Reserved address: `192.168.1.121` for MAC `e0:51:d8:12:d2:66`
- Reboot state: reboot completed; the DHCP reservation was verified with a
  read-only Talos query
- Boot media: physical USB prepared and successfully reached the Talos v1.12.12
  boot menu
- Internal target: `/dev/nvme0n1`, AirDisk 256 GB; erasure explicitly approved
- Hardware observed: Intel N100, 4 cores, 16 GB RAM, wired interface `enp3s0`
- Talos config applied: no
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

Start `S02`: decrypt only into ignored temporary storage, render and review the
control-plane configuration, validate it with the pinned client, then re-query
the N100 at `192.168.1.121` and match its MAC and install disk before any apply.
Do not bootstrap etcd in S02.

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

- Review the rendered control-plane configuration in S02 without committing it.
- Inventory both N150 nodes and approve their exact install disks.
- Confirm reservations for `192.168.1.122` and `192.168.1.123`.
- Confirm LAN CIDR, gateway, DHCP pool, DNS and NTP.
- Record JetKVM authentication, firmware and Tailscale state.

## Session log

| Session | State | Result |
|---|---|---|
| `S00` | Complete | Media verified; N100 and reserved `.121` address verified in maintenance mode |
| `S01` | Complete | Age recovery copy confirmed; encrypted Talos inputs, patches, render/validate scripts, and clean local control-plane validation |
| `S02` | Not started | Render, review and install the control plane |
| `S03` | Not started | Bootstrap and verify the single-node cluster |
| `S04A` | Not started | Inventory and install worker 1 |
| `S04B` | Not started | Inventory and install worker 2 |
| `S05` | Not started | Baseline workload and failure exercise |
| `S06` | Not started | Tailscale operator and access controls |
| `S07` | Not started | Full teardown and reproducible rebuild |
| `S08` | Deferred | Virtualization and Cluster API experiment |
