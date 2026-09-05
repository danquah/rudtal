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
| Tailscale OAuth secret | Lets the operator create or manage tagged tailnet devices | Give minimal scopes; store only in a SOPS-encrypted Kubernetes Secret |
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

If plaintext cluster secrets or a rendered machine config enter Git history, do
not rely on deleting the file from the latest commit. Generate a new Talos secrets
bundle and rebuild the lab. Revoke and replace any exposed Tailscale credential.

The files under `rudtal01/` were generated for the stranded cluster and include
private keys and tokens. They are explicitly ignored. Do not use them for the new
cluster, and do not initialize or publish a Git history that includes them.
