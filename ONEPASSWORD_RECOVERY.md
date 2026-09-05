# 1Password-backed SOPS recovery

This runbook will be completed and executed in S09. It defines the intended trust
boundary now so later cluster work does not accumulate unnecessary credential
backups.

## Design

The private Git repository contains the SOPS-encrypted Talos secrets bundle and
the public age recipient. A dedicated 1Password item contains the corresponding
private age identity. Access to either one alone is insufficient:

```text
private Git repository                     1Password vault
talos/secrets.sops.yaml                     Rudtal age identity
              \                              /
               \                            /
                SOPS decrypts cluster identity
                            |
                  render Talos machine config
                            |
            reproduce talosconfig; retrieve kubeconfig
```

SOPS supports age identities from a file, an environment value or a command.
There is no native 1Password key backend in the documented SOPS backend list. The
preferred bridge is `SOPS_AGE_KEY_CMD`: SOPS executes a helper, the helper calls
`op read`, and SOPS consumes the returned identity without a permanent key file.

References:

- <https://github.com/getsops/sops#encrypting-using-age>
- <https://www.1password.dev/cli/secrets-scripts>
- <https://www.1password.dev/cli/reference/commands/read>

## 1Password item

Create the item interactively in the 1Password UI so the private value never
enters terminal history. Use a dedicated vault if practical and a name without
spaces to simplify secret references.

Suggested fields:

| Field | Type | Contents |
|---|---|---|
| `age-identity` | Concealed/password | The single age private-identity line from `rudtal.txt` |
| `public-recipient` | Text | Public `age1...` recipient from `.sops.yaml` |
| `purpose` | Text | Decrypt Rudtal SOPS files and reproduce Talos credentials |
| `created` | Date/text | Identity creation date |
| `rotation` | Text | Link or reference to the repository rotation procedure |

Do not store generated machine configuration as a document in the item. Do not
make `talosconfig` or `kubeconfig` the recovery source; both can be reproduced or
retrieved after recovering the encrypted Talos identity.

## Preferred command integration

S09 will add a helper with this behavior:

```sh
#!/bin/sh
set -eu
: "${RUDTAL_AGE_OP_REF:?Set RUDTAL_AGE_OP_REF to the 1Password secret reference}"
exec op read "$RUDTAL_AGE_OP_REF"
```

The second machine supplies the reference locally, for example:

```sh
export RUDTAL_AGE_OP_REF='op://<vault>/<item>/age-identity'
export SOPS_AGE_KEY_CMD="$PWD/scripts/age-key-from-1password.sh"
unset SOPS_AGE_KEY_FILE SOPS_AGE_KEY
```

The first variable contains a location, not the age identity. The helper's stdout
is consumed by SOPS. Project scripts must not echo it, capture it in shell tracing,
or place it in a tracked file.

## Second-machine acceptance test

Use a trusted machine or a clean OS account with no Rudtal age key already
installed:

1. Install Git, SOPS, age, the 1Password CLI and the pinned Talos client. Arrange
   access to the private Git remote separately; possession of the age identity
   does not grant repository access.
2. Sign in to 1Password using the normal interactive or desktop-integrated flow.
3. Clone the private repository and confirm the encrypted file reports as
   encrypted with `sops filestatus talos/secrets.sops.yaml`.
4. Set `RUDTAL_AGE_OP_REF` and `SOPS_AGE_KEY_CMD` as shown above.
5. Derive only the public recipient and compare it with `.sops.yaml`:

   ```sh
   scripts/age-key-from-1password.sh | age-keygen -y
   ```

6. Prove decryption without displaying plaintext:

   ```sh
   sops --decrypt --output /dev/null talos/secrets.sops.yaml
   ```

7. Run the repository secret validation, render the control-plane configuration
   into ignored storage, and validate it. Do not apply it to a node.
8. Sign out of 1Password or remove access to the item and verify that the same
   decryption command fails when no file-based age identity is present.

The test is complete only when success and denied-access behavior are both
observed and recorded without exposing the private identity or decrypted Talos
data.

## File-based fallback

When `SOPS_AGE_KEY_CMD` cannot be used, restore the identity directly to its
protected file without printing it:

```sh
install -d -m 700 "$HOME/.config/sops/age"
op read --out-file "$HOME/.config/sops/age/rudtal.txt" --file-mode 0600 \
  'op://<vault>/<item>/age-identity'
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/rudtal.txt"
sops --decrypt --output /dev/null talos/secrets.sops.yaml
```

If this is a temporary recovery machine, remove the restored file after the test.
If it is a new trusted administration machine, retain it only with full-disk
encryption and normal user-account protections. In either case, never commit it or
copy it into the repository.

## Rotation and loss scenarios

- If a machine is lost but its disk encryption and account protections remain
  trustworthy, revoke its access where possible and decide whether risk warrants
  age-key rotation.
- If the age identity or 1Password item may have been exposed, generate a new age
  identity, add its public recipient to `.sops.yaml`, use `sops updatekeys` on each
  encrypted file, verify recovery with the new identity, then remove the old
  recipient and delete the compromised item.
- If the encrypted Talos secrets themselves were exposed together with the age
  identity, create a new Talos cluster identity and rebuild rather than only
  rotating the SOPS wrapper key.
- If 1Password access is lost but a trusted local age identity remains, restore
  account access and create a new 1Password recovery item. If neither copy exists,
  the encrypted Talos identity is unrecoverable and the lab must be rebuilt with a
  new identity.
