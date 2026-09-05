# Lab inventory

Fill this in before generating physical machine configuration. Values marked
`TBD` are deliberately not inferred from the old cluster files.

## Machines

| Node | Model | CPU | RAM | SSD model / size | Wired MAC | Firmware | Talos install disk | Wipe approved |
|---|---|---|---:|---|---|---|---|---|
| `rudtal-cp-1` | G3 | N100 | 16 GB | AirDisk 256 GB | `e0:51:d8:12:d2:66` | TBD | `/dev/nvme0n1` | Yes |
| `rudtal-worker-1` | G3 Plus | N150 | 16 GB | TWSC TSC3AN512E6-F2T60S / 512 GB | `e0:51:d8:1a:80:37` | SMBIOS firmware version unavailable (`Default string`) | `/dev/nvme0n1` | TBD |
| `rudtal-worker-2` | G3 Plus | N150 | TBD | TBD | TBD | TBD | Confirm from maintenance mode | TBD |

Do not copy `/dev/nvme0n1` or `/dev/sda` from the stranded configuration without
checking the disks shown by each machine in Talos maintenance mode.
For `rudtal-worker-1`, maintenance mode showed the internal NVMe disk as
`/dev/nvme0n1`, the physical installer USB as `/dev/sda`, and JetKVM virtual
media as `/dev/sr0`. Only the NVMe disk is the prospective install target.
No worker disk wipe was approved in S04A; approval remains `TBD`.

## Network

| Item | Proposed value | Confirmed |
|---|---|---|
| LAN CIDR | `192.168.1.0/24` | TBD |
| Gateway | `192.168.1.1` | TBD |
| DHCP pool | TBD | TBD |
| `rudtal-cp-1` | `192.168.1.121` | Confirmed after reboot for `e0:51:d8:12:d2:66` |
| `rudtal-worker-1` | `192.168.1.122` | Confirmed after reboot for `e0:51:d8:1a:80:37` |
| `rudtal-worker-2` | `192.168.1.123` | TBD |
| Kubernetes API endpoint | `192.168.1.121:6443` | Confirmed after S03 bootstrap and `/readyz` check |
| Kubernetes API DNS | `api.rudtal.home.arpa` | TBD |
| DNS servers | TBD | TBD |
| NTP reachable | TBD | TBD |
| Public port forwards to lab | None | TBD |

The first maintenance boot received `192.168.1.12`. After adding the router
reservation and rebooting, `rudtal-cp-1` was reached and re-identified at
`192.168.1.121` on 2026-09-05.
The first N150 maintenance boot was observed at `192.168.1.122` on wired
interface `enp3s0` with MAC `e0:51:d8:1a:80:37`. The router reservation was
verified after reboot on 2026-09-05.

## Access and recovery

- [x] JetKVM is available for firmware, console and boot troubleshooting.
- [x] JetKVM can emulate the Talos installer as a virtual drive.
- [x] A physical USB has a `TALOS_1` boot partition and reusable `DATA` partition.
- [ ] JetKVM local authentication is password-protected.
- [ ] JetKVM firmware is current and its recovery procedure is recorded.
- [ ] JetKVM is enrolled in Tailscale with a dedicated tag and restrictive policy.
- [ ] How JetKVM will be moved or switched among the three NUCs is recorded.
- [ ] Each node is connected by wired Ethernet.
- [x] The router can reserve addresses or exclude the proposed static range from DHCP.
- [ ] The Tailscale account can create OAuth clients and edit tailnet policy.
- [ ] An independent Tailscale subnet-router candidate is identified if remote `talosctl` access is wanted.
- [ ] The age private identity will be backed up outside Git.

## Decisions

- Git repository visibility: TBD (`private` recommended)
- First rehearsal: TBD (`QEMU on the admin Mac` recommended)
- Initial topology: one schedulable control plane and two workers
- Initial CNI: Flannel
- Initial storage: disposable node-local storage
- Later virtualization experiment: Proxmox + CAPMOX, after one bare-metal rebuild
- JetKVM target switching method: TBD (move cables or use a compatible KVM switch)
