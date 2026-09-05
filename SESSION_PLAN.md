# Session plan

The sessions below are small enough to run separately with Codex or Claude Code.
Each one starts from repository state rather than chat history and ends with a
reviewable artifact or an observed checkpoint. The operator stays at the console
for installation, bootstrap, reset and credential-backup steps.

At the start of every session, tell the agent:

> Read `AGENTS.md`, `STATUS.md`, `SECURITY.md` and the relevant session in
> `SESSION_PLAN.md`. Work only on that session. Explain each machine-changing
> command before running it so I can follow along. Update `STATUS.md` and the
> relevant runbook before finishing.

## S00: finish control-plane discovery

Goal: prove that the N100's router reservation works before generating or applying
configuration.

Work:

1. Boot normal Talos v1.12.12 from the prepared USB.
2. Confirm that maintenance mode shows `192.168.1.121`.
3. Query disks, links, CPU and memory with the exact v1.12.12 `talosctl` and
   `--insecure`.
4. Match MAC `e0:51:d8:12:d2:66` and install disk `/dev/nvme0n1`.
5. Update `INVENTORY.md` and `STATUS.md`.

Stop condition: the reservation and hardware identity are recorded. Do not apply
a Talos machine configuration in this session.

Suggested prompt:

> Continue Rudtal session S00. The N100 has rebooted; help me verify the address
> and maintenance-mode inventory, update the handoff files, and stop before
> applying configuration.

## S01: repository and encrypted configuration pipeline

Goal: make Git contain all reproducible inputs and no plaintext credentials.

Work:

1. Create a dedicated age identity at `~/.config/sops/age/rudtal.txt`, mode 0600.
2. Show only its public recipient. Pause while the operator stores the private
   identity in a password manager; never print its private contents.
3. Add `.sops.yaml`, `versions.env`, Talos patch directories and render/validate
   scripts.
4. Generate fresh Talos secrets into ignored temporary storage and immediately
   encrypt them as `talos/secrets.sops.yaml`.
5. Create common, role and `rudtal-cp-1` patches using DHCP and the verified install
   disk. Keep `cluster.allowSchedulingOnControlPlanes: true` explicit.
6. Scan the Git candidate set for private keys and tokens, review the diff, then
   create the initial commit if the operator has supplied the desired Git identity.

Stop condition: encrypted source and scripts exist, secret scanning is clean, and
the age recovery copy is confirmed. Do not contact or modify a node.

## S02: render, review and install the control plane

Goal: install only the verified N100 from a reviewed, reproducible config.

Work:

1. Decrypt the SOPS secrets only into ignored temporary storage.
2. Render the control-plane config with Talos v1.12.12 and Kubernetes v1.35.8.
3. Validate it and summarize its networking, install disk, endpoint, hostname and
   scheduling settings without displaying embedded secrets.
4. Re-query maintenance mode at `192.168.1.121` and match the expected MAC and
   `/dev/nvme0n1` immediately before applying.
5. With the operator watching JetKVM, apply the config, let Talos install, unmount
   boot media, reboot from the internal SSD and verify Talos health.
6. Update the runbook and `STATUS.md`.

Stop condition: the control-plane node runs from its internal SSD and answers the
authenticated Talos API. Do not bootstrap etcd in this session.

## S03: bootstrap and verify the single-node cluster

Goal: create Kubernetes on the installed control-plane node.

Work:

1. Bootstrap etcd exactly once.
2. Retrieve `kubeconfig` into ignored local state.
3. Wait for the Kubernetes node and system pods to become healthy.
4. Confirm the control plane is schedulable and deploy one tiny disposable test
   workload.
5. Record commands, observations and recovery checks.

Stop condition: the N100 is `Ready`, core system pods are healthy, and the test
workload runs. Do not add Tailscale or workers.

## S04A and S04B: add one worker per session

Goal: discover and install one N150 without assuming it matches the other.

Repeat separately for `rudtal-worker-1` at `.122` and `rudtal-worker-2` at `.123`:

1. Move or switch JetKVM, boot installation media and inventory RAM, SSD, NIC,
   firmware and Talos disk names.
2. Approve the exact internal disk and create/test its DHCP reservation.
3. Add the node patch, render and validate its worker config.
4. Recheck MAC and disk immediately before applying the config.
5. Install, unmount media, reboot, and wait for the node to become `Ready`.
6. Update inventory, status and Git history.

Stop condition: the one named worker is `Ready`. Never reuse the first worker's
disk or interface assumptions without checking.

## S05: baseline and failure exercise

Goal: understand the behavior and resource use of the chosen topology.

Work:

1. Record idle CPU and memory use on all nodes.
2. Run a small replicated workload and expose it only on the LAN.
3. Stop the control plane with the operator present; observe existing workloads,
   API availability and recovery after restart.
4. Document why this is acceptable for the lab and what three control planes would
   change.

Stop condition: baseline and failure observations are in Git and the cluster is
healthy again.

## S06: Tailscale

Goal: provide narrowly scoped tailnet access without public router forwarding.

Work:

1. Review and record JetKVM's separate Tailscale and local-authentication posture.
2. Design tags and grants/ACLs before creating credentials.
3. Create a dedicated least-privilege OAuth client with the operator in the
   Tailscale UI; store its secret only in SOPS-encrypted form.
4. Install the pinned Kubernetes Operator, expose one test service, then configure
   Kubernetes API access and RBAC.
5. Test allowed and denied identities from outside the LAN.

Stop condition: remote access works through Tailscale, denied access is tested,
and no public port forward exists.

## S07: teardown and rebuild proof

Goal: show that Git plus the external age identity is sufficient to rebuild the
lab.

Work:

1. Write and review a precise destruction/rebuild checklist.
2. Confirm no workload state matters and deliberately reset the nodes one at a
   time.
3. Re-render, reinstall, bootstrap and restore platform manifests using only the
   repository and backed-up age identity.
4. Time the rebuild and fix every undocumented step.
5. Separately document how to rotate to an entirely new cluster identity.

Stop condition: a clean rebuild succeeds and its procedure is usable without chat
history.

## S08: virtualization and Cluster API branch

Start this only after S07. Use one planning session to compare a local QEMU
management cluster with Proxmox plus CAPMOX on the physical hosts. Verify current
compatibility from primary project documentation at that time. Keep this work on a
Git branch because installing Proxmox replaces the direct bare-metal Talos design.

Stop condition for the planning session: a version compatibility matrix, network
and storage design, credential model, migration path and explicit go/no-go decision
exist. Implementation should then be split into its own sessions.

## End-of-session protocol

Every agent session must:

1. Update `STATUS.md`: current checkpoint, completed session, exact next action and
   unresolved facts.
2. Update `INVENTORY.md` or a runbook when hardware or procedures were learned.
3. Run `git status --short --ignored` and check that generated credentials remain
   ignored.
4. Summarize validation and any physical state, including which media is mounted
   and which device will boot next.
5. Leave no plaintext secret in a tracked path or terminal transcript.
