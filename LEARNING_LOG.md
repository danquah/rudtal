# Rudtal learning log

This file turns the build history into an administration guide. It explains the
state and trust boundaries without storing credentials. Future sessions append an
entry using the template at the end.

## Mental model

The lab has several layers that fail and recover differently:

```text
Firmware and boot media
        ↓
Talos Linux and its machine API (talosctl, port 50000)
        ↓
etcd and Kubernetes control-plane components
        ↓
Kubernetes nodes, CNI and workloads (kubectl, API port 6443)
        ↓
Optional services such as Tailscale
```

`talosctl` administers the operating system and Kubernetes control-plane services.
`kubectl` administers Kubernetes objects after the API server exists. JetKVM is a
separate console and boot-recovery path that still works when those APIs do not.

## S00: boot media and maintenance discovery

### What happened

The Talos v1.12.12 ISO was copied to a FAT32 partition named `TALOS_1` on a
multi-partition physical USB. The N100 booted that installer into memory. Booting
the installer did not write Talos to the internal SSD; it exposed the Talos API in
maintenance mode so the hardware could be inspected first.

The node initially received `192.168.1.12`. Its active wired interface was
identified as `enp3s0` with MAC `e0:51:d8:12:d2:66`, and the router was configured
to reserve `192.168.1.121` for that MAC. After reboot, the reservation was verified.

Talos reported two writable disks with very different roles:

- `nvme0n1`: internal 256 GB AirDisk, chosen as the installation target;
- `sda`: external 123 GB SanDisk, the installer USB.

### Administrative lesson

Maintenance mode is Talos before it has a machine identity and trusted client
configuration. Read-only discovery commands use `--insecure` because the node has
not received the cluster CA or API certificates yet. The flag is appropriate only
for this initial local maintenance boundary.

Linux disk names can change across machines. Size, model, serial, transport and MAC
address are stronger evidence than copying a device name from another node.

Useful pattern:

```sh
talosctl --nodes <maintenance-ip> get links --insecure
talosctl --nodes <maintenance-ip> get disks --insecure
```

Recovery is simple at this stage: reboot from the verified USB and repeat discovery.

Optional exercise: explain why selecting `sda` as the install disk would destroy
the installer USB instead of installing to the N100's internal SSD.

## S01: reproducible configuration and secrets

### What happened

The repository gained pinned Talos and Kubernetes versions, shared/role/node
patches, rendering scripts and a fresh Talos secrets bundle encrypted with SOPS.
The age private identity lives outside Git at
`~/.config/sops/age/rudtal.txt`, while `.sops.yaml` contains only its public
recipient. A recovery copy of the private identity was stored in the password
manager.

### Administrative lesson

Talos machine configurations contain credentials even when the visible purpose is
ordinary networking or installation. They are rendered into ignored `generated/`
storage and treated as secrets. Git stores declarative patches and the
SOPS-encrypted cluster identity.

The trust chain has distinct pieces:

- the Talos secrets bundle is the durable cluster identity and contains CA/signing
  material and bootstrap secrets;
- SOPS encrypts that bundle for one or more age public recipients;
- the age private identity decrypts it and therefore stays outside Git;
- `talosconfig` is a client credential for the Talos API;
- `kubeconfig` is a client credential for the Kubernetes API.

Pinning the client and server version makes regeneration predictable. Rendering is
safe to repeat because it uses the same encrypted secrets; generating a new Talos
secrets bundle creates a different cluster identity.

Useful commands are wrapped by:

```sh
scripts/validate.sh secrets
scripts/render.sh controlplane rudtal-cp-1
scripts/validate.sh generated/rudtal-cp-1/controlplane.yaml
```

Recovery requires the Git repository plus the backed-up age identity. Losing the
age identity means the encrypted cluster identity cannot be recovered.

Optional exercise: identify which repository file is safe to publish and which
external file must stay private when using age public-key encryption.

## S02: control-plane installation and authenticated Talos

### What happened

The control-plane configuration was rendered and validated locally. Immediately
before apply, the node at `192.168.1.121` was matched to the expected wired MAC and
the 256 GB internal `nvme0n1`. The initial configuration was applied through
maintenance mode, Talos installed to that disk, and the node rebooted. The
generated `talosconfig` then authenticated successfully with RBAC enabled. Talos
reported `nvme0n1` as its system disk.

### Administrative lesson

Applying the first machine configuration crosses two boundaries at once: it writes
the chosen system disk and gives the node its cluster identity. That is why the
MAC/disk check happened immediately before the command.

The first apply uses `--insecure` only because maintenance mode has no trusted
cluster certificate yet. After configuration, `talosctl` uses the client
certificate in `talosconfig` and the server uses certificates rooted in the Talos
CA. RBAC is then enforced.

The authenticated verification pattern is:

```sh
talosctl --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.121 version
talosctl --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.121 get systemdisk
```

If installation fails, boot the recovery USB, rediscover the hardware and inspect
the failure before applying again. Do not use `--insecure` for routine management
of an installed node.

Optional exercise: describe the evidence needed before safely applying a machine
configuration to a maintenance-mode node.

## S03: etcd bootstrap and Kubernetes startup

### What happened

Etcd was bootstrapped once on `rudtal-cp-1`. Kubernetes v1.35.8 then started its
API server, controller manager, scheduler, CoreDNS, kube-proxy and Flannel. A
kubeconfig was written to ignored `state/kubeconfig`. The node became Ready and,
because this lab deliberately schedules on its single control plane, a BusyBox
smoke pod ran there.

### Administrative lesson

Bootstrap initializes the etcd data store and establishes the first member of the
cluster. It is a one-time creation operation, unlike health checks or ordinary
configuration reconciliation. Do not rerun it on an initialized cluster.

Etcd stores Kubernetes control-plane state. The API server reads and writes that
state; the scheduler chooses nodes for pending pods; the controller manager drives
actual state toward declared state. Flannel provides pod networking. CoreDNS gives
services and pods cluster DNS.

`talosconfig` and `kubeconfig` administer different layers. Use `talosctl` for the
machine, services, logs and etcd-level recovery. Use `kubectl` for nodes, pods,
deployments, services and Kubernetes RBAC.

Useful checks:

```sh
kubectl --kubeconfig state/kubeconfig get nodes -o wide
kubectl --kubeconfig state/kubeconfig get pods -n kube-system -o wide
talosctl --talosconfig generated/rudtal-cp-1/talosconfig health
```

The smoke pod can be removed safely because its state is disposable:

```sh
kubectl --kubeconfig state/kubeconfig delete pod s03-smoke --ignore-not-found
```

Recovery depends on the failed layer. A failed workload can be recreated through
Kubernetes. A failed control-plane process is inspected through Talos. Loss of the
single etcd member makes this lab's Kubernetes API unavailable and calls for the
deliberate recovery or rebuild procedure.

Optional exercise: use the current status to explain why workloads can run on this
control plane even though production clusters commonly keep it tainted.

## S04A discovery: identifying the first worker

### What happened

The first N150 booted Talos v1.12.12 in maintenance mode. Its wired interface was
identified as `enp3s0` with MAC `e0:51:d8:1a:80:37`. The router reservation for
`192.168.1.122` was verified after reboot. Talos reported an Intel N150 with four
cores, 16 GB RAM and three distinct storage devices:

- `nvme0n1`: internal 512 GB TWSC NVMe, the prospective installation target;
- `sda`: external 123 GB SanDisk physical USB;
- `sr0`: read-only JetKVM virtual media.

No worker configuration was rendered or applied, and the NVMe has not yet been
approved for erasure.

### Administrative lesson

A worker does not need a separate manually created Kubernetes join token in this
design. Its rendered Talos machine configuration will contain the cluster trust
material derived from the same encrypted Talos secrets bundle. After installation,
Talos starts kubelet and the node presents its identity to the existing Kubernetes
control plane. That trust step belongs to the installation half of S04A.

The discovery step is deliberately separate because an IP address identifies a
current network lease, while the wired MAC identifies the interface used for the
router reservation. Disk model, size, serial and transport distinguish the
internal installation target from attached recovery media. The repeated read-only
queries are safe; applying a worker configuration is the later destructive step.

Useful maintenance-mode checks:

```sh
talosctl --nodes 192.168.1.122 get links --insecure
talosctl --nodes 192.168.1.122 get disks --insecure
talosctl --nodes 192.168.1.122 get processors --insecure
talosctl --nodes 192.168.1.122 get memorymodules --insecure
```

If the reservation does not produce `.122`, keep the node in maintenance mode,
verify the router entry against the observed MAC, and reboot. Do not embed a
guessed address or apply configuration as a workaround.

Optional exercise: use the recorded model, size and transport fields to explain
why `nvme0n1`, rather than `sda` or `sr0`, is the proposed worker install disk.

## S04A: install the first worker

### What happened

The operator explicitly approved erasing `rudtal-worker-1`'s internal
`/dev/nvme0n1` (TWSC TSC3AN512E6-F2T60S, 512 GB) before rendering or applying
the worker configuration. The worker config was rendered locally from the same
encrypted Talos secrets bundle as the control plane and passed strict metal
validation. The final maintenance-mode check still matched the reserved address
`192.168.1.122`, wired MAC `e0:51:d8:1a:80:37`, and the approved internal NVMe.

The pinned Talos client applied the config with `--insecure`. Talos installed to
the NVMe and rebooted. The operator then removed the physical USB and unmounted
JetKVM's virtual CD/DVD media, so the next boot source is the installed system.
The generated worker config remains under ignored `generated/`; the encrypted
source remains in `talos/secrets.sops.yaml`; the Kubernetes client credential
remains in ignored `state/kubeconfig`.

Authenticated Talos verification reported server v1.12.12 with RBAC enabled,
system disk `nvme0n1`, and kubelet `Running`/`OK`. Kubernetes registered
`rudtal-worker-1` at `192.168.1.122` and reported it `Ready` on v1.35.8. The
control plane also remained `Ready`.

### Administrative lesson

A worker configuration has three important kinds of content: the node role and
hostname, cluster-wide networking and Kubernetes version settings, and the
cluster trust material needed for Talos and kubelet to join the existing
cluster. The worker does not bootstrap etcd or receive a manually created join
token in this design. The same encrypted Talos secrets establish the cluster
identity; the existing Talos client identity authenticates administrative
requests, while kubelet establishes its node identity with the Kubernetes API.

The initial `apply-config --insecure` is a narrow exception for a maintenance
mode node with no installed trust identity. Once installed, use the
authenticated `talosconfig` for `version`, `get systemdisk`, `services`, health
checks and recovery. Kubernetes checks use `state/kubeconfig` and `kubectl`.
`--insecure` must not become the routine management path.

Useful commands:

```sh
INSTALL_DISK=/dev/nvme0n1 ./scripts/render.sh worker rudtal-worker-1
./scripts/validate.sh generated/rudtal-worker-1/worker.yaml
downloads/talosctl-v1.12.12-darwin-arm64 \
  --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.122 get systemdisk
downloads/talosctl-v1.12.12-darwin-arm64 \
  --talosconfig generated/rudtal-cp-1/talosconfig \
  --nodes 192.168.1.122 services
KUBECONFIG=state/kubeconfig kubectl \
  wait --for=condition=Ready node/rudtal-worker-1 --timeout=180s
KUBECONFIG=state/kubeconfig kubectl get nodes -o wide
```

Rendering and validation are safe to repeat locally. Initial apply is
destructive to the selected disk and should be preceded in every installation
by matching the live address, wired MAC, disk model/size and transport.
If a worker returns to the installer, remove or unmount its boot media and
reboot. If Talos or kubelet fails, use authenticated Talos service status and
logs first; do not rerun etcd bootstrap. If the NVMe was erased, recovery is a
reinstall from corrected configuration, not restoration of its prior contents.

Optional exercise: explain why the final check needed both the wired MAC and
the disk model/transport, and why `--insecure` is appropriate for the first
maintenance-mode apply but not for the later `version` query.

## Entry template

```markdown
## SXX: title

### What happened

Describe the observed before/after state and where the new state lives.

### Administrative lesson

Explain the components, trust or lifecycle boundary, reusable commands, success
evidence, safe repetition and recovery path.

Optional exercise: one small, reversible observation or explanation task.
```
