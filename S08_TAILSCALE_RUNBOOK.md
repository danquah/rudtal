# S08 Tailscale Operator and access controls

Status: preparation on `experiment/tailscale-s08`. No Tailscale account,
JetKVM, Talos, router, or Kubernetes state has changed while preparing this
runbook.

## Scope and ownership

S08 adds a tailnet-only path for **routine Kubernetes observation**. It does
not change Talos machine API access, Cilium configuration, node addresses,
router forwarding, subnet routes, exit nodes, applications, or JetKVM. Talos
and direct LAN `state/kubeconfig` administration remain the recovery paths.

| Configuration | Owner | Declarative location or external location |
| --- | --- | --- |
| Operator, CRDs, ProxyGroup and routine RBAC | Flux / Kubernetes | `infrastructure/controllers/tailscale/`, `infrastructure/configs/tailscale/` |
| OAuth client, tags, grants, HTTPS and device inventory | Tailscale | Tailscale admin console; policy fragment in `docs/policies/tailscale-s08.hujson` |
| OAuth secret value | Kubernetes bootstrap exception | cluster-only `tailscale/operator-oauth`; password-manager record chosen by operator |
| Node OS, port 50000 and Talos client certificates | Talos | unchanged; separate from S08 |
| Router port forwarding and JetKVM | router / JetKVM | unchanged; separately reviewed before any JetKVM decision |

## Architecture

```text
approved Tailscale user device
  └─ HTTPS 443 over tailnet grant only
       └─ 2x tag:rudtal-k8s-api ProxyGroup Pods
            └─ authenticated Kubernetes API proxy
                 └─ impersonates group rudtal-k8s-routine-readers
                      └─ ClusterRole read-only inventory and Flux status

No tailnet grant → Talos API, LAN node addresses, Operator device,
subnet route, exit node, JetKVM, or future Service proxy.
```

The ProxyGroup is selected over the in-process proxy because its two replicas
are independent of the Operator Deployment and pre-provision API certificates.
It uses `auth` mode: Tailscale authenticates the caller, the proxy adds only the
approved Kubernetes group, and Kubernetes RBAC decides resource verbs. `noauth`
is intentionally not used.

## Version and artifact decision

Tailscale's official stable Helm index on 2026-09-06 selected chart and
application version `1.102.3`. Helm 3.19.0 fetched the chart; its SHA-256 was
`c2440014df04fdf1b67b53daa4290d7b878584cf4702f9b1b50f51ba64499a6a`, matching
the index. The repository pins the chart version, all immediately usable images,
and the API proxy image index digests:

| Artifact | Pin |
| --- | --- |
| Helm chart | `tailscale-operator` `1.102.3`; archive SHA-256 `c244…99a6a` |
| Operator | `tailscale/k8s-operator:v1.102.3@sha256:d86a…eb12` |
| Generic future proxy default | `tailscale/tailscale:v1.102.3@sha256:8c42…f680` |
| API ProxyGroup | `tailscale/k8s-proxy:v1.102.3@sha256:82de…d4546` |

The stable HTTP Helm repository is Tailscale's supported distribution. It is
not an OCI source, so Flux cannot pin it with an `OCIRepository` manifest
identity as it does Cilium. Flux pins the exact chart version and records the
HTTP index artifact revision; the checked archive checksum is kept here for
review. No chart provenance or Cosign verifier is configured because Tailscale
has not published one in the selected installation path. That is a known,
reviewed supply-chain limit, not a signature claim.

Kubernetes `1.35.8` exceeds Tailscale's documented minimum `1.23`; Cilium runs
with kube-proxy retained, so its documented kube-proxy-replacement caveat does
not apply. Tailscale recommends equal operator and proxy versions; all selected
operator/proxy images use `v1.102.3`.

## Tailnet policy and OAuth client

Merge `docs/policies/tailscale-s08.hujson` into the existing policy after
replacing only `REPLACE_WITH_TAILSCALE_LOGIN`. It introduces three tags:

- `tag:rudtal-k8s-operator`: OAuth identity and Operator device;
- `tag:rudtal-k8s-api`: the only proxy reachable by the routine-reader group;
- `tag:rudtal-k8s-unexposed`: safe default for a future Service/Ingress proxy;
  it has no connectivity grant or Service auto-approval.

The fragment also lets only `tag:rudtal-k8s-api` advertise the API's Tailscale
Service. Before saving it, enable Tailscale HTTPS for the tailnet and use the
admin-console policy editor to validate the merged policy and its tests.

The OAuth client is created in **Tailscale → Settings → Trust credentials**
with `tag:rudtal-k8s-operator` and exactly these write scopes, which Tailscale
requires for the Operator:

- General / Services;
- Devices / Core;
- Keys / Auth Keys.

Do not request broad/all scope, OAuth app device provisioning, a subnet-router
route, exit-node permission, or a JetKVM tag. Store the generated secret in the
operator-selected password-manager record. Tailscale shows it once; never paste
it in chat, a shell argument, Git, a policy file, or terminal output.

## Kubernetes authorization

`infrastructure/configs/tailscale/rbac.yaml` binds the impersonated group
`rudtal-k8s-routine-readers` to `rudtal-k8s-routine-reader`. It can get/list/watch
nodes, namespaces, Pod metadata, Services, Events, standard workload controllers,
Jobs/CronJobs, and Flux source/Kustomization/HelmRelease status. It cannot read
Secrets or ConfigMaps, read Pod logs, exec/attach/port-forward, create, patch,
update, or delete. Kubernetes RBAC is additive; a later binding can broaden this
group, so inspect every ClusterRoleBinding subject before changing it.

Expected proof after activation from a Tailscale-connected machine:

```sh
KUBECONFIG=state/tailscale-kubeconfig \
  tailscale configure kubeconfig https://<ProxyGroup-status-URL>
KUBECONFIG=state/tailscale-kubeconfig kubectl auth can-i list nodes
# yes
KUBECONFIG=state/tailscale-kubeconfig kubectl auth can-i get secrets --all-namespaces
# no
```

`state/tailscale-kubeconfig` is ignored. It is a local connection configuration,
not a Kubernetes credential that can administer Talos. The explicit environment
variable prevents the Tailscale CLI from changing a default kubeconfig.

## Bootstrap, rebuild, rotation, and removal

### Chosen credential boundary: bootstrapped Kubernetes Secret

S08 uses an explicitly bootstrapped `tailscale/operator-oauth` Secret. Before
promoting the Flux configuration, create the OAuth client and run:

```sh
RUDTAL_KUBECONFIG=state/kubeconfig ./scripts/bootstrap-tailscale-oauth.sh
```

The helper creates the `tailscale` namespace if needed, asks for the client ID
and secret without echoing the secret, materializes protected temporary files,
and creates or updates the Secret through `--from-file` paths. It removes the
temporary directory on exit. The chart deliberately leaves OAuth values empty,
so it mounts that pre-created Secret rather than rendering secret data from Git.

This is a documented bootstrap exception. The client ID and secret exist only in
the password manager and Kubernetes Secret storage; Helm release history may
also retain effective values, so `tailscale` namespace read access is privileged.
Never grant the routine-reader group access to it.

A SOPS-encrypted GitOps Secret would make Git durable but requires a **second**
Flux decryption age identity, its own pre-bootstrap Kubernetes Secret, password
manager backup, rotation, recovery procedure, and Flux SOPS wiring. Loading the
Talos break-glass age identity into Flux would collapse distinct trust boundaries
and is forbidden. For this disposable lab before S10's 1Password recovery work,
the bootstrap Secret has fewer durable secrets and a clearer rebuild boundary:
retrieve the operator credential from the password manager and rerun this helper
after Flux exists. S10 may revisit a separately protected Flux identity only as
an explicitly reviewed design; it must not reuse the Talos age identity.

Rotate by creating a replacement OAuth client with the same three scopes and
operator tag, storing the new value, running the helper, restarting only the
Operator Deployment, and proving the Operator plus ProxyGroup still work before
revoking the old client in Tailscale. Do not rotate by editing Helm values.

For a rebuild, recreate the Tailscale OAuth client only if it was revoked;
otherwise retrieve its password-manager record and bootstrap this same Secret
before enabling the Git source that contains the Tailscale HelmRelease, then
reconcile Flux. For permanent removal: revoke the OAuth client, delete the
policy grants and tag ownership, remove these Git declarations and reconcile
with prune, then confirm Operator and ProxyGroup devices disappear from the
Tailscale Machines page. Deleting the ProxyGroup first removes the remote API
endpoint; direct LAN administration remains available throughout.

## Inspection and troubleshooting

Use non-secret metadata only:

```sh
KUBECONFIG=state/kubeconfig flux get sources helm -A
KUBECONFIG=state/kubeconfig flux get helmreleases -A
KUBECONFIG=state/kubeconfig kubectl get proxygroup rudtal-k8s-api
KUBECONFIG=state/kubeconfig kubectl get pods -n tailscale
KUBECONFIG=state/kubeconfig kubectl get clusterrole,clusterrolebinding \
  rudtal-k8s-routine-reader,rudtal-k8s-routine-readers
```

If the HelmRelease cannot mount `operator-oauth`, do not add OAuth values to
Git: rerun the helper, inspect Secret metadata only, then reconcile the narrow
HelmRelease. If the ProxyGroup is not ready, inspect its conditions and the
Operator Pod logs without printing Secret data. If tailnet connectivity fails,
inspect Tailscale HTTPS, the merged grant, tag ownership, and Machines-page
device tags. If `can-i` is unexpectedly broad, inspect all bindings for the
impersonated group; permissions cannot be denied by a narrower Role.

## JetKVM review gate

JetKVM is not an S08 workload or Kubernetes proxy. Before any JetKVM change,
review its current local password/authentication state, firmware version and
upgrade recovery path, Tailscale enrollment/tag/device identity, and whether its
Tailscale path is limited to the console UI rather than a subnet route. Record
only the posture and recovery procedure, never passwords, device keys or
screenshots containing credentials. The current repository has no verified
answer for any of these fields; do not infer one from Kubernetes or this
Operator.

## References checked 2026-09-06

- [Tailscale Operator installation](https://tailscale.com/docs/kubernetes-operator/install-operator)
- [API proxy setup](https://tailscale.com/docs/kubernetes-operator/api-server-access/setup-api-over-tailscale)
- [API proxy authentication and RBAC](https://tailscale.com/docs/kubernetes-operator/api-server-access/auth-and-rbac)
- [Operator compatibility](https://tailscale.com/docs/kubernetes-operator/reference/compatibility)
- [Tailscale OAuth clients](https://tailscale.com/docs/features/oauth-clients)
- [Tailscale policy grants](https://tailscale.com/docs/reference/syntax/grants)
- [Flux HelmRepository](https://fluxcd.io/flux/components/source/helmrepositories/)
- [Flux HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
