# Tailscale API ProxyGroup canary

Status: planned follow-up to S08. The working in-process API proxy remains the
routine endpoint until this canary independently passes every acceptance check.

## Question to answer

Can Tailscale Operator `1.102.3` provide a reproducible two-replica
`kube-apiserver` ProxyGroup on this cluster, while preserving the working
in-process proxy as an independent recovery path?

The ProxyGroup is useful as a learning exercise and separates proxy Pods from
the Operator Pod. It does not make the Kubernetes control plane highly
available: Rudtal still has one API server and one etcd member on
`rudtal-cp-1`. Its practical benefit is retaining the tailnet endpoint across a
single proxy Pod or Operator Pod restart while the control-plane node remains
healthy.

## Why S08 did not settle the question

S08 ran two healthy ProxyGroup Pods for roughly nine hours, but the
`ProxyGroup` never advertised its Tailscale Service or populated its HTTPS URL.
The generated TLS Secret stayed empty. The worker restored service by removing
the canary and enabling the documented in-process proxy.

Two separate concerns need a controlled retest:

1. The S08 policy allowed only TCP `443`. Tailscale's current API ProxyGroup
   setup instructions require clients to be allowed on both TCP `80` and
   `443`.
2. Tailscale `1.102.3` contains a possible circular first-certificate path. In
   `cmd/k8s-operator/api-server-proxy-pg.go`, the operator waits for a non-empty
   TLS Secret before adding the service to `AdvertiseServices`. In
   `kube/certs/certs.go`, the certificate loop waits until the service domain is
   an allowed certificate domain. Tailscale issue
   [#20716](https://github.com/tailscale/tailscale/issues/20716) records the same
   advertise/certificate cycle for HTTPS-only ingress ProxyGroups. That issue
   is not proof that the API ProxyGroup path is identical, so this canary should
   collect evidence rather than assume either outcome.

The earlier TCP certificate-discovery defect in Tailscale issue
[#19019](https://github.com/tailscale/tailscale/issues/19019) is a different
problem and was fixed before `1.102.3`; the pinned source discovers
`TerminateTLS` domains.

## Supervision boundary

Repository work, local validation, read-only cluster inspection and preparation
of an additive policy fragment can run unattended. The experiment must stop at
**G1** unless the operator has reviewed and applied the exact tailnet policy.
No worker may infer account authorization from the existing unrestricted
single-user network grant.

After G1, deploying and removing the isolated canary are reversible Kubernetes,
Git and Flux operations. They may run unattended only when the worker prompt
explicitly authorizes promotion of the reviewed canary commit to `main` and its
automatic rollback on failure. A worker must never edit the Tailscale account,
rotate the OAuth client, inspect its secret value, or devise a live Secret patch
to bypass the certificate gate while unattended.

## Invariants

- Keep `apiServerProxyConfig.mode: "true"`; the working in-process proxy must
  remain available throughout the experiment.
- Keep `apiServerProxyConfig.allowImpersonation: "true"` and reuse the existing
  `tailscale/operator-oauth` Secret. Do not create or rotate credentials.
- Use auth mode. Do not test `noauth`.
- Do not alter Talos, Cilium, node roles, router forwarding, JetKVM, subnet
  routes, exit nodes, or public exposure.
- Use a distinct name and hostname, initially
  `rudtal-k8s-api-canary`, so existing kubeconfig contexts remain valid.
- Pin the `tailscale/k8s-proxy:v1.102.3` multi-architecture index
  `sha256:82de09cb7b97b7e59201c21af2d4a189d688e448948b092c2e020b3ccd9d4546`
  through a `ProxyClass`; Docker Hub resolved it on 2026-09-07.
- Require the two replicas to run on different Kubernetes nodes with pod
  anti-affinity using the generated label
  `tailscale.com/parent-resource: rudtal-k8s-api-canary` and topology key
  `kubernetes.io/hostname`.
- Never print Secret data, kubeconfig contents, generated auth keys or
  credential-bearing proxy configuration. Certificate/key byte lengths may be
  reported without their content.

## G0: unattended preparation

1. Start from clean, synchronized `main`; create
   `experiment/tailscale-proxygroup-s08c`.
2. Recheck the official ProxyGroup setup, API reference and current open issues.
   Record the date and distinguish documentation from inference.
3. Verify the current baseline without changing it: all nodes Ready, Cilium and
   CoreDNS healthy, all Flux objects Ready, Tailscale Operator Ready, the
   in-process endpoint usable, and the routine allowed/denied RBAC checks still
   return `yes`/`no`.
4. Restore a `ProxyClass` and two-replica `ProxyGroup` as a separate canary.
   Keep the existing in-process proxy enabled. Add required cross-node
   anti-affinity and retain exact image/version pins.
5. Prepare the additive tailnet policy shown below, adapting it to the complete
   existing policy without deleting or replacing unrelated rules.
6. Run Kustomize builds, schema checks available from the installed CRDs,
   policy syntax/tests, `git diff --check`, and a tracked-secret scan. Commit the
   credential-free candidate on the experiment branch.
7. Present the exact diff, official references, expected tailnet objects and
   rollback. Stop at G1; do not push or apply account/cluster changes unless the
   required authorization was explicitly supplied.

Candidate policy additions:

```hujson
"tagOwners": {
  "tag:rudtal-k8s-api": ["tag:rudtal-k8s-operator"],
},
"autoApprovers": {
  "services": {
    "svc:rudtal-k8s-api-canary": ["tag:rudtal-k8s-api"],
  },
},
"grants": [
  {
    "src": ["group:rudtal-k8s-routine-readers"],
    "dst": ["tag:rudtal-k8s-api"],
    "ip": ["tcp:80", "tcp:443"],
    "app": {
      "tailscale.com/cap/kubernetes": [
        { "impersonate": { "groups": ["rudtal-k8s-routine-readers"] } },
      ],
    },
  },
],
```

This is a fragment, not a replacement policy. The existing Operator tag owner,
in-process grant and unrelated rules must remain. The user should apply it in
the Tailscale policy editor and confirm that its policy tests pass.

## G1: supervised account gate

Before cluster deployment, the human operator must confirm all of the following:

- the merged tailnet policy retains the working in-process proxy access;
- `tag:rudtal-k8s-api` is owned by `tag:rudtal-k8s-operator`;
- only `svc:rudtal-k8s-api-canary` is auto-approved for
  `tag:rudtal-k8s-api`;
- the routine-reader grant permits TCP `80` and `443` to the canary tag and
  carries only the existing Kubernetes impersonation group;
- no broad OAuth scope, new credential, public port, route, exit node or JetKVM
  change was introduced;
- the reviewed Git commit may be promoted to `main` and automatically reverted
  if the canary fails.

Without that confirmation, an unattended worker finishes after G0 with a
handoff. Elapsed time is never approval.

## G2: unattended canary deployment

1. Promote only the reviewed canary commit through the normal `main`/Flux path.
   Do not point Flux at the experiment branch and do not imperatively apply a
   second source of truth.
2. Wait for Flux reconciliation and inspect the `ProxyClass`, `ProxyGroup`,
   StatefulSet, Pods, Events and non-secret Operator/proxy logs.
3. Prove both replicas are Running on distinct nodes. Record all ProxyGroup
   conditions, especially `ProxyGroupReady`, `ProxyGroupAvailable`,
   `KubeAPIServerProxyValid` and `KubeAPIServerProxyConfigured`.
4. Observe certificate progress using metadata and byte lengths only. Never
   retrieve or display `tls.crt`, `tls.key`, state Secrets or generated proxy
   configuration.
5. Wait up to 20 minutes for the HTTPS URL. This spans the documented one- and
   ten-minute certificate retry intervals while bounding an otherwise silent
   wait. Longer elapsed time is evidence, not a reason to improvise.
6. If Ready, create a separate ignored
   `state/tailscale-proxygroup-kubeconfig` from the reported URL. Prove `list
   nodes` is allowed and `get secrets --all-namespaces` is denied.
7. Delete one canary proxy Pod and verify the canary endpoint remains usable
   through the other replica. After recovery to two replicas on distinct nodes,
   roll the Operator Deployment and verify the canary endpoint remains usable.
   Do not reboot or disrupt a physical node during an unattended run.
8. Confirm the in-process endpoint, LAN kubeconfig, nodes, Cilium, DNS, Flux and
   both HelmReleases remain healthy.

## Failure handling

If the URL or certificate does not become ready within 20 minutes, capture:

- ProxyGroup conditions and Events;
- Pod readiness and node placement;
- TLS Secret existence and certificate/key byte lengths only;
- whether the Tailscale Service exists and is approved, using account metadata
  supplied by the user;
- sanitized Operator and `k8s-proxy` log messages;
- the exact pinned source paths involved in the wait.

Do not patch generated config Secrets, scale the Operator down, manually add
`AdvertiseServices`, request a certificate from inside a Pod, or upgrade to an
unreviewed image. Those actions cross the supported ownership boundary and can
expose auth material or create an irreproducible success.

Revert the canary commit through Git and Flux, wait for its StatefulSet, Pods,
Services, RBAC and generated tailnet devices to be removed, and reconfirm the
working in-process endpoint. The additive tailnet policy may remain temporarily
for diagnosis because it grants no Kubernetes endpoint after the tagged canary
devices disappear; remove it with the user in the next supervised account
session.

## Success and landing

The ProxyGroup can replace the in-process endpoint only after:

- all four relevant ProxyGroup conditions are True and the HTTPS URL is stable;
- two replicas are scheduled on distinct physical nodes;
- allowed and denied RBAC checks pass through its dedicated kubeconfig;
- access survives deletion of either proxy Pod and an Operator rollout;
- the original in-process and LAN paths remain proven during the canary;
- Flux owns all durable Kubernetes objects and no credentials are tracked;
- resource usage and the remaining single-control-plane limitation are
  documented.

Landing the canary does not automatically disable the in-process proxy. Make
that a separate reviewed decision after observing the ProxyGroup for at least
one day. If the pinned release still exhibits the certificate/advertisement
cycle, retain the in-process endpoint and repeat this plan only after an
upstream fix is identified in a pinned stable release.

## References checked 2026-09-07

- [Tailscale API server proxy overview](https://tailscale.com/docs/kubernetes-operator/api-server-access)
- [Tailscale API ProxyGroup setup](https://tailscale.com/docs/kubernetes-operator/api-server-access/setup-api-over-tailscale)
- [Tailscale ProxyGroup API](https://github.com/tailscale/tailscale/blob/v1.102.3/k8s-operator/api.md)
- [Tailscale issue #20716](https://github.com/tailscale/tailscale/issues/20716)
- [Tailscale issue #19019](https://github.com/tailscale/tailscale/issues/19019)
