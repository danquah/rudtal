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

At session end, follow the protocol in `SESSION_PLAN.md`. A session is incomplete
until the handoff records the actual physical and repository state.
