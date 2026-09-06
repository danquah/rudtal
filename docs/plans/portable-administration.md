# Portable administration plan

Status: design for S10A and S10B. No tool installer, credential, or access path
is implemented by S07A.

## Goal and trust boundaries

A trusted macOS or Linux machine should be able to clone this private repository,
install the exact command-line tools into the clone, and obtain the least access
needed for the current task. Git authentication is a prerequisite for cloning;
Tailscale and 1Password authentication are separate prerequisites and must never
be treated as proof of Git access.

The design has three access levels:

| Level | Intended use | Credential source |
|---|---|---|
| Routine Kubernetes | inspect workloads and perform RBAC-authorized operations | Tailscale Kubernetes API proxy plus Kubernetes RBAC |
| Talos reader/operator | inspect a node, or perform an explicitly authorized machine operation | short-lived `os:reader` or `os:operator` Talos client stored separately in 1Password |
| Break-glass recovery | recreate full Talos administration after loss or rebuild | SOPS-encrypted Talos secrets plus the age identity from 1Password |

Routine access must not decrypt `talos/secrets.sops.yaml`. A Kubernetes
`kubeconfig` does not grant access to the Talos machine API, and a Talos client
certificate does not replace Kubernetes RBAC.

## Repository-local tools

S10A will add a credentialless installer that supports Darwin and Linux on
`amd64` and `arm64`. It installs only below ignored `.tools/bin/`, uses an
ignored download cache, and never uses `curl | sh`, `sudo`, a system package
manager, or a global PATH mutation.

Track the version, upstream URL pattern and SHA-256 for every supported platform
in one reviewable manifest. Do not encode the workstation architecture in
`versions.env`. The initial tool set is:

- `talosctl`, `kubectl`, Flux CLI and Helm for cluster administration;
- SOPS and age for break-glass rendering;
- Cosign for signed OCI artifact verification.

The installer must detect OS and architecture, reject unsupported combinations,
download to a temporary file, verify the pinned checksum before installation,
and install atomically with mode `0755`. Re-running it with matching binaries is
safe. A version mismatch must fail or require an explicit reviewed replacement.

Git, Tailscale and the 1Password CLI remain external prerequisites because their
installation and interactive account enrollment are platform- and identity-
specific. The repository checks their presence and authenticated state without
attempting to sign in.

## Operator entry point

S10A will add one small wrapper, tentatively `./scripts/rudtal`, with these
subcommands:

| Subcommand | Behavior |
|---|---|
| `doctor` | check OS/architecture, Git worktree, required external commands, file modes and available auth without printing credential data |
| `tools` | install or verify the pinned repository-local binaries |
| `routine-access` | create an ignored kubeconfig through the Tailscale API proxy and verify the caller's Kubernetes RBAC |
| `recover-admin` | explicitly enter the 1Password/SOPS break-glass path, regenerate Talos client configuration, and retrieve a fresh kubeconfig |
| `status` | run non-secret Talos, Kubernetes and Flux health summaries using explicit config paths |
| `clean` | remove only named generated credentials and temporary files below this repository after proving each path is inside the worktree |

Every command uses a repository-derived absolute root, sets `umask 077`, creates
credential directories with mode `0700`, and creates kubeconfig/talosconfig files
with mode `0600`. It must not rely on `$HOME/bin`, the caller's current directory,
or an implicit default kubeconfig/talosconfig. Shell tracing is forbidden around
credential commands.

## Routine Kubernetes access

After S08 establishes the Tailscale Kubernetes Operator API proxy, S10A will
document and automate `tailscale configure kubeconfig` into an ignored path.
Tailscale supplies the authenticated identity; the API proxy impersonates that
identity; Kubernetes RoleBindings or ClusterRoleBindings decide what it may do.
Acceptance must test one allowed action and one denied action. The wrapper should
show `kubectl auth can-i` results before any mutating operation.

This path is suitable for a temporary trusted machine because signing out of
Tailscale and deleting the local kubeconfig removes its local access material.
Tailnet policy and Kubernetes RBAC remain the durable authorization controls.

## Talos access and break-glass recovery

S10A will test role-scoped Talos clients generated with the pinned `talosctl`:

- an `os:reader` client for routine machine inspection;
- an `os:operator` client only for named administrative procedures;
- short certificate lifetimes chosen and recorded during implementation.

Store each scoped client in a separate concealed 1Password item from the age
identity. Retrieval writes directly to ignored state with mode `0600`; expiry is
verified before use. Talos client certificates are not individually revocable,
so expiry is the normal containment mechanism and suspected compromise may
require rotating the Talos CA or rebuilding the lab identity.

`recover-admin` is deliberately separate. It uses `RUDTAL_AGE_OP_REF` and
`SOPS_AGE_KEY_CMD` as documented in `ONEPASSWORD_RECOVERY.md`, validates the
public age recipient, decrypt-tests to `/dev/null`, and renders only an ignored
Talos configuration. It then retrieves a fresh kubeconfig through the Talos API.
It never stores decrypted `talos/secrets.sops.yaml`, prints a private identity,
or treats an old kubeconfig as the recovery source.

## S10A implementation and local validation

S10A is complete when a stronger review session has:

1. implemented the manifest, installer and wrapper without touching the live
   cluster or any external account;
2. removed the architecture-specific Flux tool fields from `versions.env` in
   favor of the multi-platform manifest;
3. added help text and a concise operator runbook for every subcommand;
4. added credentialless tests for platform selection, checksum failure, modes,
   idempotence, unsupported platforms and safe cleanup;
5. added macOS/Linux CI across `amd64` and `arm64` where runners exist, with all
   account- and cluster-facing commands replaced by fixtures;
6. proved that tracked files and test logs contain no secret-shaped output.

## S10B clean-machine drill

S10B runs only after S10A review and after S08 provides the Tailscale API proxy.
Use a second trusted machine or clean OS account with no Rudtal tools or
credentials already present:

1. authenticate to Git separately and clone the private repository;
2. run `doctor`, install the pinned local tools, and verify their versions;
3. authenticate to Tailscale and prove routine Kubernetes allowed/denied RBAC;
4. retrieve and verify an `os:reader` Talos client, then remove it;
5. authenticate to 1Password and complete the break-glass decrypt-test, Talos
   render/validation and fresh kubeconfig retrieval without displaying secrets;
6. run `clean`, sign out, and prove the removed local credentials no longer work;
7. record timings, missing prerequisites and every manual step in the durable
   runbook.

S10B succeeds when the operator can recover from Git and 1Password without chat
history, routine access works without the SOPS age identity, denied access is
observed, and the temporary machine can be returned to a credential-free state.
