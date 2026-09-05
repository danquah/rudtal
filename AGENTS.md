# Agent instructions for Rudtal

This repository is operated across short sessions with Codex and Claude Code.
Treat repository files as the durable memory; do not rely on previous chat.

Before doing work, read `STATUS.md`, `SESSION_PLAN.md`, `SECURITY.md`,
`INVENTORY.md` and the relevant runbook. Follow the session named by the operator
and update `STATUS.md` before finishing.

The operator is learning and wants to participate. Before a command changes a
physical node, erases a disk, bootstraps etcd, resets a node, creates an external
credential or changes a Tailscale account, explain the command, its expected
effect and the recovery path. Perform read-only discovery and local reversible
repository work directly.

## Teaching protocol

Treat explanation as part of the work, not as an optional final summary. Use plain
language and connect every command to the Talos or Kubernetes component it
affects. Do not paste unexplained command output.

Before a meaningful administrative action, briefly explain:

1. the goal and which layer is involved: firmware/boot, Talos machine API, etcd,
   Kubernetes control plane, node, workload, networking or credentials;
2. what the command and its important flags mean;
3. what durable or runtime state it will change;
4. what success should look like and how recovery works if it fails.

After the action, compare the observed result with the expectation. Point out the
one or two output fields that establish the conclusion. Distinguish operations
that are safe to repeat from one-time or destructive operations.

At the end of every session, add a concise entry to `LEARNING_LOG.md` covering:

- the mental model and new concepts;
- what was changed and where that state lives;
- the administrative commands used and when they are useful again;
- verification and recovery steps;
- one small optional exercise the operator can perform to reinforce the lesson.

Keep explanations proportional. Routine repeated checks can refer back to an
earlier entry, while new trust, storage, networking and lifecycle operations need
full explanations. Never include secret values or credential-bearing output in a
lesson.

Safety rules:

- Never read, display, commit or reuse credential-bearing files in `rudtal01/`.
- Never print an age private identity, Talos secret bundle, rendered machine
  config, `talosconfig`, `kubeconfig` or Tailscale secret.
- Keep plaintext and rendered output under ignored `generated/` or `state/` and
  remove it when its immediate use is complete.
- Before applying or resetting Talos, match endpoint, wired MAC and install disk
  against `INVENTORY.md` in the same session.
- Do not apply configuration to a temporary DHCP discovery address when a reserved
  address is expected.
- Bootstrap etcd exactly once, in session S03.
- Use `downloads/talosctl-v1.12.12-darwin-arm64` for the pinned v1.12.12 cluster;
  the global binary is older.
- Verify changing versions and Cluster API compatibility against primary upstream
  documentation and record the date.
- Preserve user edits and never rewrite Git history to clean a credential leak;
  rotate the affected credential or cluster identity.
- When implementing S09, use the 1Password UI for entering the private age
  identity. Never print `op read` output. Prefer `SOPS_AGE_KEY_CMD` and use
  `op read --out-file ... --file-mode 0600` only for the documented fallback.

At session end, follow the protocol in `SESSION_PLAN.md`. A session is incomplete
until the handoff records the actual physical and repository state and the
learning log explains what the operator did and learned.
