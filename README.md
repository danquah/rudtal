# Rudtal

A rebuildable Talos Kubernetes learning lab for three GMKtec mini PCs.

For a new Codex or Claude Code session, start with [STATUS.md](STATUS.md), then
choose the next bounded task from [SESSION_PLAN.md](SESSION_PLAN.md). Shared agent
rules live in [AGENTS.md](AGENTS.md); `CLAUDE.md` directs Claude Code to the same
rules. [LEARNING_LOG.md](LEARNING_LOG.md) explains what each completed session
changed and builds a practical Talos administration reference as the lab grows.
[ONEPASSWORD_RECOVERY.md](ONEPASSWORD_RECOVERY.md) defines the final
cross-machine credential-recovery drill.

Start with [PROJECT_PLAN.md](PROJECT_PLAN.md). It explains the recommended
architecture, learning stages, Git layout, Tailscale integration and the later
virtualization/Cluster API experiment. [SECURITY.md](SECURITY.md) defines which
artifacts may be committed. Fill in [INVENTORY.md](INVENTORY.md) before generating
or applying physical machine configuration. [INSTALL_MEDIA.md](INSTALL_MEDIA.md)
records the verified installer and JetKVM/USB procedure.

The `rudtal01/` directory is stranded generated output from an earlier Talos 1.9.5
attempt. It contains live-looking private keys and tokens. Its generated files are
ignored and must not be reused for the new cluster.
