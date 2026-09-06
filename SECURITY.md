# Security and secret handling

This repository describes a disposable lab, but its credentials can still grant
administrator access to machines, Kubernetes, and the Tailscale account.

## Credential classes

| Artifact | What it grants | Repository treatment |
|---|---|---|
| Talos `secrets.yaml` | Root cluster identity, CA keys, bootstrap tokens and Kubernetes signing material | Commit only as SOPS-encrypted `secrets.sops.yaml` |
| Rendered Talos machine config | Node bootstrap configuration and embedded cluster credentials | Generate under ignored `generated/`; never commit |
| `talosconfig` | Talos API client identity and roles | Keep outside Git; issue separate, shorter-lived client certificates |
| `kubeconfig` | Kubernetes API client identity | Keep outside Git; regenerate and rotate as needed |
| SOPS age identity | Decrypts every secret encrypted to it | Keep outside Git and back up in a password manager |
| 1Password secret reference | Locates the age identity but does not itself contain it | Supply locally; keep account, vault and item names out of public Git |
| Tailscale OAuth secret | Lets the operator create or manage tagged tailnet devices | Give minimal scopes; S08 uses a documented cluster-only bootstrap Secret rather than Git plaintext or the Talos age identity |
| JetKVM | Full keyboard, console and virtual boot-media control over an attached node | Require a local password, a dedicated Tailscale tag and narrowly scoped tailnet access |

Talos rotates server-side certificates automatically. Client certificates in
`talosconfig` and `kubeconfig` remain the operator's responsibility. Renew them at
least yearly; use shorter lifetimes while learning certificate issuance and RBAC.

Use `talosctl apply-config --insecure` only against a node in maintenance mode for
its initial configuration. After configuration, require the mutual-TLS client
identity from `talosconfig`.

Treat JetKVM as an administrator credential with physical-equivalent access. Keep
its firmware current, use its local password, and avoid public port forwarding.
Tailscale access to JetKVM provides the console path; it is not a subnet route to
the Talos or Kubernetes APIs unless routing is separately configured and approved.
Unmount installer media after each node has installed successfully.

## Configuration ownership

Talos owns the operating system, kubelet, control-plane services, etcd and the
initial cluster identity. Kubernetes add-ons are a separate layer: Flux, Cilium,
Tailscale and later applications should be declared under the repository's
Kubernetes directories and reconciled by Flux. A one-time bootstrap exception is
acceptable for Flux itself and for Cilium when no pod network exists yet; record
that exception and transfer ownership to Git as soon as the controllers are
healthy. Pin chart and image versions. Keep credentials in SOPS-encrypted
Secrets or a narrowly documented, cluster-only bootstrap Secret; never load the
Talos age identity into Flux. Document any emergency imperative change so Git
can be made authoritative again.

If plaintext cluster secrets or a rendered machine config enter Git history, do
not rely on deleting the file from the latest commit. Generate a new Talos secrets
bundle and rebuild the lab. Revoke and replace any exposed Tailscale credential.

The files under `rudtal01/` were generated for the stranded cluster and include
private keys and tokens. They are explicitly ignored. Do not use them for the new
cluster, and do not initialize or publish a Git history that includes them.

## 1Password recovery boundary

SOPS does not list 1Password as a native key backend. It does support
`SOPS_AGE_KEY_CMD`, which runs a command whose output supplies the age identity.
The preferred integration is therefore a small helper that calls `op read` using a
locally supplied 1Password secret reference. The command and environment contain
only the reference; the private identity travels through process output directly
to SOPS and is never printed by project scripts.

Store only the dedicated Rudtal age identity in the 1Password item. Generated
machine configs, `talosconfig` and `kubeconfig` remain derived, short-lived local
artifacts. A file-based recovery is permitted when necessary using `op read
--out-file` with mode 0600, but the guide must state whether that restored file is
the trusted machine's durable identity or a temporary file that should be removed.

Never enable shell tracing around `op read`, place the private identity in a
command-line argument, command substitution or tracked environment file, or use a
pipeline that displays it. Test recovery with decryption output directed to
`/dev/null` and compare only the derived public recipient.
