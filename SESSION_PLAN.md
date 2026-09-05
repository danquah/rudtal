# Session plan

The sessions below are small enough to run separately with Codex or Claude Code.
Each one starts from repository state rather than chat history and ends with a
reviewable artifact or an observed checkpoint. The operator stays at the console
for installation, bootstrap, reset and credential-backup steps.

Each session also has a teaching deliverable. The agent explains new commands
before using them, interprets the important result afterward, and updates
`LEARNING_LOG.md`. The explanation should answer four practical questions: what
component was touched, why the operation was needed, where its state lives, and
how an administrator verifies or recovers it later.

At the start of every session, tell the agent:

> Read `AGENTS.md`, `STATUS.md`, `SECURITY.md` and the relevant session in
> `SESSION_PLAN.md`. Work only on that session. Explain each machine-changing
> command before running it so I can follow along. Teach me the Talos and
> Kubernetes concepts behind the work, interpret important output, and update
> `LEARNING_LOG.md`, `STATUS.md`, and the relevant runbook before finishing.

## Learning map

| Session | Concepts to explain |
|---|---|
| `S00` | UEFI boot flow, installer versus installed system, maintenance mode, DHCP identity, Talos resource queries and Linux disk names |
| `S01` | Talos PKI and cluster identity, SOPS envelope encryption, age recipients and identities, source inputs versus rendered credentials, version pinning |
| `S02` | Machine configuration lifecycle, why initial apply uses `--insecure`, transition to mTLS/RBAC, system disk selection and installation recovery |
| `S03` | Why etcd bootstrap happens once, etcd quorum, static control-plane pods, kubeconfig versus talosconfig, CNI startup and scheduling |
| `S04A/B` | Worker trust and joining, node identity, DHCP reservations, kubelet registration, certificates and node readiness |
| `S05` | Control plane versus data plane, desired state and reconciliation, workload controllers, service routing and failure behavior |
| `S06` | GitOps reconciliation, Talos versus Kubernetes ownership, HelmRelease/Kustomization, bootstrap exceptions, Git credentials and encrypted Kubernetes secrets |
| `S07` | CNI replacement, Cilium datapath, kube-proxy choices, Talos machine configuration, Helm values, network policy and rollback |
| `S08` | Tailnet identity, Kubernetes authentication and RBAC, operator credentials, tags/grants, service exposure and recovery access |
| `S09` | Declarative rebuilds, cluster identity versus workload state, credential rotation, reset scope and recovery testing |
| `S10` | 1Password secret references, SOPS key sources, cross-machine recovery, credential exposure boundaries and recovery verification |
| `S11` | Durable runbooks versus project history, repository information architecture, reference migration, clean-clone validation and secret hygiene |

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

1. Bootstrap etcd exactly once for the initial cluster generation.
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

## S06: declarative Kubernetes add-on management

Goal: establish a Git-controlled boundary for Kubernetes resources outside the
Talos machine configuration before installing Cilium or Tailscale.

Work:

1. Decide and document the repository layout for Kubernetes declarations, for
   example `clusters/rudtal/`, `infrastructure/` and `apps/`. Explain which state
   remains in `talos/` and which state belongs to Kubernetes.
2. Choose a GitOps controller after comparing current workflows. Flux is the
   recommended first experiment because its bootstrap creates the controllers and
   Git sync resources, after which Git changes can drive cluster operations. Pin
   the chosen controller versions.
3. Define the bootstrap exception: an operator with cluster-admin and Git push
   access performs the initial Flux bootstrap. Thereafter use Git-managed
   Kustomizations and HelmReleases; document emergency breaks from that rule.
4. Install Flux against the running Flannel cluster, using a narrowly scoped
   deploy key or equivalent Git credential. Keep that credential encrypted and
   out of normal manifests.
5. Commit one harmless, disposable test resource and reconcile it from Git. Prove
   drift correction by changing the live object and observing Git restore it.
6. Define rules for Helm chart versions, image digests where practical, values,
   SOPS-encrypted Kubernetes Secrets and dependency ordering. Treat HelmRelease
   and Kustomization status as administrative evidence.

Stop condition: Flux is healthy and demonstrably reconciling one disposable
resource from Git; the repository layout, bootstrap credential boundary and
rollback procedure are documented. Do not install Tailscale or Cilium in S06.

## S07: Cilium rebuild experiment

Goal: replace Flannel with Cilium in a disposable rebuild, while learning how a
cluster-wide CNI change interacts with Talos configuration and Git-managed add-ons.

Keep the current Flannel cluster as the known-good baseline. Use a Git branch or
tag for this experiment and do not attempt an unplanned in-place CNI swap.

Work:

1. Read the current Talos and Cilium compatibility guidance and pin a Cilium
   version. Record whether the first pass keeps kube-proxy or enables Cilium's
   kube-proxy replacement. Start with kube-proxy retained for a smaller change;
   make kube-proxy replacement a separate measured sub-experiment.
2. Add a Talos patch for `cluster.network.cni.name: none` and, only if the chosen
   kube-proxy-free mode requires it, `cluster.proxy.disabled: true`. Explain why
   Cilium's Talos guidance changes these machine-level settings.
3. Add Cilium's HelmRepository/HelmRelease or equivalent pinned declarations to
   the GitOps tree. Record Talos-specific settings, including removal of
   `SYS_MODULE`, reuse of Talos-provided cgroupv2/bpffs mounts, Kubernetes IPAM,
   and API endpoint settings required by the selected kube-proxy mode.
4. Reset and rebuild a fresh cluster generation from the Cilium branch. Bootstrap
   etcd exactly once for that generation, treat the initial Cilium installation
   as a documented bootstrap exception if Flux cannot run before pod networking
   exists, and hand management to Flux as soon as Cilium is healthy.
5. Verify Cilium agents and operator on every node, pod-to-pod and pod-to-service
   connectivity, DNS, NodePort behavior and a simple CiliumNetworkPolicy. Record
   the difference between Talos host networking, CNI pod networking and eBPF
   service handling.
6. If kube-proxy replacement is selected later, measure service behavior before
   and after, verify the API endpoint through the documented KubePrism or other
   host path, and record the rollback path. Never remove kube-proxy until that
   path is proven.

Stop condition: the Cilium branch is either healthy and reproducible from Git, or
has been cleanly discarded with the Flannel baseline restored. The test includes a
documented rollback and no untracked imperative resources.

## S08: Tailscale with declarative add-on management

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

## S09: teardown and rebuild proof

Goal: show that Git plus the external age identity is sufficient to rebuild the
lab.

Work:

1. Write and review a precise destruction/rebuild checklist.
2. Confirm no workload state matters and deliberately reset the nodes one at a
   time.
3. Re-render, reinstall, bootstrap etcd exactly once for the fresh generation,
   and restore platform manifests using only the repository and backed-up age
   identity.
4. Time the rebuild and fix every undocumented step.
5. Separately document how to rotate to an entirely new cluster identity.

Stop condition: a clean rebuild succeeds and its procedure is usable without chat
history.

## S10: 1Password and cross-machine recovery drill

Run this after S09. The detailed design
and command patterns live in `ONEPASSWORD_RECOVERY.md`.

Goal: prove that Git plus access to the correct 1Password item is enough to recover
the SOPS decryption capability on another trusted machine without copying
`talosconfig`, `kubeconfig` or plaintext Talos secrets between machines.

Work:

1. In the 1Password UI, create a dedicated item whose concealed field contains
   the Rudtal age private-identity line. Record its public recipient, creation date,
   purpose and rotation instructions in non-secret fields. Do not enter the
   private identity through shell history or display it during verification.
2. Install and authenticate the 1Password CLI on a second trusted machine. Clone
   the private Git repository and install the pinned or documented versions of
   SOPS, age and `talosctl`. Document the separate Git authentication prerequisite;
   the age identity does not grant repository access.
3. Add a small repository script that returns the age identity with `op read` from
   a secret reference supplied locally through `RUDTAL_AGE_OP_REF`. Configure SOPS
   through `SOPS_AGE_KEY_CMD`, so the age identity passes directly from the
   1Password CLI to SOPS and is not persistently written to disk.
4. Update `render.sh` and `validate.sh` to accept either the existing
   `SOPS_AGE_KEY_FILE` recovery path or `SOPS_AGE_KEY_CMD`. Keep the 1Password
   vault/item reference outside tracked files; commit only a placeholder example.
5. Derive and compare only the public age recipient with `.sops.yaml`. Validate
   decryption to `/dev/null`, then render and validate the control-plane config in
   ignored storage. Do not display decrypted YAML or apply it to a node.
6. Test the documented fallback: use `op read --out-file ... --file-mode 0600` to
   restore the age identity when command-based integration is unavailable, verify
   decryption, and securely remove that temporary local copy if it is not intended
   to remain on the trusted machine.
7. Write the exact setup, recovery, verification, rotation and lost-access
   procedure in `ONEPASSWORD_RECOVERY.md`. Record which 1Password account and
   vault are required without committing account identifiers or vault/item names.

Stop condition: a second machine with no pre-existing Rudtal age identity can
decrypt-test `talos/secrets.sops.yaml` without emitting plaintext, render a valid
ignored machine config, and explain how `talosconfig` and `kubeconfig` can be
recreated. The test must also prove that removing 1Password access makes
decryption fail.

## S11: repository curation and durable handoff

Run this only after S10, when the installation, rebuild, GitOps and recovery
procedures have been exercised. Moving active handoff files earlier would create
avoidable churn for agents and links while the project is still changing.

Goal: turn the construction workspace into a maintainable long-lived operations
repository without changing the live cluster or Flux reconciliation paths.

Work:

1. Classify every root document as a durable entry point, an operational runbook,
   learning material or completed project history. Keep only the short `README`,
   agent entry points, version and encryption policy files, and live configuration
   directories at the root.
2. Create a coherent `docs/` tree. Distill the durable content into architecture,
   security and runbook documents; move the learning log under `docs/learning/`;
   archive the completed plan, session plan and final status under
   `docs/project-history/`. Avoid retaining multiple documents that claim to be
   the authoritative procedure for the same operation.
3. Preserve `clusters/rudtal/`, `infrastructure/`, `apps/`, `talos/`, `scripts/`,
   `.sops.yaml` and `versions.env` at their established paths unless a separately
   reviewed Flux or script migration proves a path change safe.
4. Rewrite the root `README` as a concise operator entry point: architecture,
   routine health checks, change workflow, rebuild, secret recovery and links to
   the authoritative runbooks. Update `AGENTS.md`, `CLAUDE.md` and all relative
   links for the new locations.
5. Review the stranded `rudtal01/` marker and its ignored local artifacts without
   displaying credential-bearing files. Decide whether its warning still adds
   value; if the local artifacts are retired, use a recoverable removal procedure
   and retain any necessary historical warning in the archive.
6. Validate Markdown links, Kustomize/Flux paths, render and validation scripts,
   ignore rules and the tracked file set. Scan the reachable Git history for
   credential-shaped material without printing matches. Perform a clean-clone
   documentation/recovery walkthrough and confirm Flux remains healthy and points
   at the unchanged cluster path.
7. Record the final repository map, archive the completed status, and optionally
   tag the reviewed lab baseline only after the local and remote commits match.

Stop condition: a new operator can clone the repository, find one authoritative
procedure for each routine task, understand which files are live configuration
versus history, and verify the lab without relying on the session documents or
chat history. The live cluster and Flux reconciliation graph are unchanged.

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
6. Update `LEARNING_LOG.md` with the concepts, state changes, reusable
   administrative commands, recovery notes and one optional hands-on exercise.
7. In the final response, explain the result in enough detail that the operator
   can describe what happened without relying on raw command output.
