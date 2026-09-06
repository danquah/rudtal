# Three-control-plane follow-up experiment

Status: deferred idea for a future learning session. It is not part of S07 and
must not change the current Cilium rebuild.

## Question to answer

Would running all three Rudtal nodes as schedulable control-plane nodes provide
useful availability and etcd experience without consuming too much of the N100
and N150 machines' workload capacity?

The expected incremental cost is modest: each promoted worker would also run
etcd, kube-apiserver, kube-controller-manager and kube-scheduler. A rough idle
planning estimate is 0.5–1.5 GiB RAM and 0.1–0.3 CPU per additional control
plane, plus etcd disk writes. These are estimates to measure on this hardware,
not acceptance limits. Cilium, kube-proxy and Talos already run on every node.
Keeping control-plane scheduling enabled would leave unused capacity available
to ordinary workloads.

## Learning goals

- Understand why three etcd members tolerate one unavailable member while one
  member cannot gracefully leave itself.
- Observe quorum, leader election and control-plane component placement.
- Compare idle and small-workload CPU, memory and disk activity with the current
  one-control-plane/two-worker topology.
- Practice rolling reboot, upgrade and graceful reset of one control plane while
  Kubernetes remains available.
- Understand the difference between control-plane availability and application
  availability when all three machines share one LAN and power domain.

## Future session outline

1. Finish the current Cilium, Tailscale and rebuild work first and record a
   healthy one-control-plane resource baseline.
2. Research the supported Talos procedure and choose explicitly between adding
   control-plane roles to the existing cluster and performing a fresh declarative
   three-control-plane rebuild. Prefer a fresh rebuild if it gives clearer,
   reproducible configuration and rollback.
3. Add reviewed per-node control-plane patches for `.121`, `.122` and `.123`.
   Keep all three schedulable for the first capacity experiment.
4. Render and strictly validate all machine configurations without displaying
   credentials. Verify endpoint, MAC and NVMe identity immediately before apply.
5. Establish three healthy etcd members and verify membership, leader, alarms,
   Kubernetes control-plane pods and API availability.
6. Measure per-node memory, cumulative and instantaneous CPU where available,
   disk activity and workload scheduling at idle and under one small repeatable
   workload.
7. Reboot one control plane, then perform a separately reviewed graceful removal
   or reset exercise. Confirm that the remaining two members retain quorum and
   that the API and workload stay available.
8. Decide from observed measurements whether to retain three control planes or
   rebuild the current one-control-plane/two-worker layout.

## Safety and success criteria

Do not begin with only two control planes: an even two-member etcd cluster still
requires both members for quorum and provides no single-member failure
tolerance. Before any topology change, confirm workload disposability and retain
a reviewed fresh-rebuild path to the current Git state.

The experiment succeeds when all three etcd members are healthy, loss of one
member preserves quorum and Kubernetes API access, resource costs are measured
on the actual machines, and the final retained topology is represented fully in
Git with a tested rebuild procedure.
