# Phase 0 — Preflight

## Goal

Confirm terraform/helm/kubectl can actually reach `03-terraform-app-tier`'s still-applied EKS/Floci
cluster, confirm `03`'s remote state is readable from here, confirm the `nginx`
Deployment/Service/HPA `03` applied are still live, and confirm the KEDA Helm chart itself is
reachable — before writing or planning any KEDA install code.

## Builds on

`03-terraform-app-tier` phase 3 (EKS cluster + node group + `nginx` Deployment/Service/HPA applied
against Floci) — see its `spec/spec.md` Completion Promise:
`eks_cluster_name = agentic-devops-lab-03-eks`, `eks_cluster_endpoint = https://localhost:6501`
(both Floci-emulated, not real AWS).

## Design decision: how `04` references `03`'s cluster

Decided now, documented here, not deferred to phase 1 — this shapes every resource `04` writes.

`03`'s `outputs.tf` exposes `eks_cluster_name` and `eks_cluster_endpoint`, but **not** the cluster's
CA certificate — `03`'s own `kubernetes-provider.tf` reads that directly off the
`aws_eks_cluster.app` resource it owns, not through an output. `04` doesn't own that resource, so it
can't do the same thing. Two options were considered:

1. Add a new output to `03` exposing `certificate_authority[0].data`, and have `04` consume it via
   `terraform_remote_state` alongside `eks_cluster_name`/`eks_cluster_endpoint`.
2. Have `04` re-derive the live cluster connection details itself, via its own
   `data "aws_eks_cluster" "app"` (and, if the exec-plugin auth pattern needs it,
   `data "aws_eks_cluster_auth" "app"`) keyed on `eks_cluster_name` read from `03`'s remote state.

**Decision: option 2.** It only requires `03`'s state to expose the cluster's *name* — already true,
nothing to change in `03` for this part — and re-derives everything else from the live AWS/Floci API,
the same way `aws eks update-kubeconfig` or `kubectl` itself would. This keeps `04` fully read-only
with respect to `03`'s Terraform code and state for the *cluster-access* question specifically. (Rule
5 in `spec.md` still requires touching `03`'s files for the unrelated HPA-supersession question in
phase 2 — that's a separate, unavoidable exception, not undermined by this decision.)

`04`'s `kubernetes` and `helm` provider blocks will mirror `03`'s `kubernetes-provider.tf` exec-plugin
pattern (`aws eks get-token`, with the Floci endpoint/credentials override applied conditionally on
`var.use_floci`), just sourced from `data.aws_eks_cluster.app` instead of `aws_eks_cluster.app`.

## Checks

Run the shared preflight script (same one `02`/`03` use, see `scripts/preflight-check.sh`'s header),
extended with the extra tools this use case needs beyond Terraform:

```bash
../scripts/preflight-check.sh --tools "terraform helm kubectl"
```

Same real-AWS-or-Floci choice `02`/`03` made — real AWS path stays the untested default, consistent
with both. Set `var.use_floci = true` to actually target Floci once the script confirms it's up.

- A minimal `terraform_remote_state` data source in `04` reading
  `s3://agentic-devops-lab-tfstate/03-terraform-app-tier/terraform.tfstate` resolves and exposes
  `eks_cluster_name` — proves `04` can read `03`'s state, mirroring exactly how `03` phase 0 proved it
  could read `02`'s.
- `data "aws_eks_cluster" "app"` (keyed on that name, against the Floci endpoint) resolves an
  endpoint + CA certificate without erroring — proves the option-2 pattern above actually works
  before any real resource depends on it.
- `aws eks update-kubeconfig --endpoint-url http://localhost:4566 --name agentic-devops-lab-03-eks`
  succeeds, and against the resulting kubeconfig: `kubectl get nodes` shows a `Ready` node,
  `kubectl get deployment nginx` / `kubectl get svc nginx` / `kubectl get hpa nginx` all show `03`'s
  still-applied resources — proves `03`'s cluster is still live and untouched before `04` changes
  anything.
- `helm repo add kedacore https://kedacore.github.io/charts && helm repo update && helm show chart
  kedacore/keda` resolves (read-only, no install) — confirms the chart is reachable through the
  sandbox's network policy and pins a chart version for phase 1. If the network policy blocks
  `kedacore.github.io`, that's a preflight failure to report and get an allow-rule added for, not
  something to route around silently.

## Explicitly NOT checked here (deferred to phase 1, not assumed)

Whether KEDA's operator, admission webhook, and CRDs actually install and reach `Ready`/`Established`
against Floci's k3s-backed EKS control plane. `03` proved `metrics-server` and core Deployment/
Service/HPA primitives work on Floci's EKS — it did not prove anything about custom operators,
admission webhooks, or CRD registration, which is meaningfully more surface area. This phase only
confirms the chart is *reachable and installable in principle* (`helm show chart` succeeds); phase 1
is where installing it for real against Floci gets tested empirically, per `spec.md` rule 6.

## Completion gate

- [x] `terraform version` / `helm version` / `kubectl version --client` all exit 0 — tools installed
      locally into this repo's `.bin/` (not system-wide; sandbox network policy required explicit
      allow-listing of `dl.k8s.io`, `get.helm.sh`, `awscli.amazonaws.com` first)
- [ ] Floci path confirmed working — **BLOCKED, see below**
- [ ] `terraform_remote_state` data source resolves `03`'s `eks_cluster_name` — not attempted, blocked
      by the item above
- [ ] `data "aws_eks_cluster"` resolves a live endpoint + CA cert from that name, against Floci — not
      attempted
- [ ] `kubectl get nodes/deployment/svc/hpa` shows `03`'s resources still `Ready`/`Running` — not
      attempted; per the finding below, there is currently nothing to get
- [ ] `helm show chart kedacore/keda` resolves — not attempted this run

## Notes / decisions

Cluster-access pattern decided above (option 2: re-derive via `data "aws_eks_cluster"`, don't add new
outputs to `03`) — still the right design, unaffected by the finding below.

**Real finding, checked empirically 2026-08-01, not assumed:** Floci was not running when this phase
was picked up. Two exited containers from a prior session existed (`floci-verify`, `floci-fix-verify`,
both `Exited (255)` ~2026-07-29) — no `floci` CLI was installed in this environment, so
`docker start floci-verify` was used directly instead of `floci start`. The container came back up and
`http://localhost:4566` responded, but **all emulated state was empty**:
- `aws eks list-clusters` → `{"clusters": []}` — `03`'s EKS cluster (`agentic-devops-lab-03-eks`) is
  gone.
- `aws s3api list-buckets` → `{"Buckets": []}` — the `agentic-devops-lab-tfstate` bucket holding every
  use case's remote Terraform state doesn't exist on this Floci instance.
- `aws dynamodb list-tables` → `{"TableNames": []}` — the `agentic-devops-lab-tflocks` lock table is
  also gone.

**Conclusion: Floci does not persist state across container restarts** (or at least not across
whatever gap happened here) — restarting an exited container brings the process back but not its
data, unlike a normal Docker volume-backed service. This means `03`'s applied EKS/nginx/HPA
infrastructure only ever existed for the lifetime of the Floci container it was applied against, and
that container's data is gone now. `03`'s own remote state is also unreachable here, since its S3
backend bucket doesn't exist on this instance either.

This is a genuine blocker for phase 0, not a phase-1 concern: there is currently no live `03` cluster
for `04` to reference, and `03`'s Terraform state itself can't be read without first re-seeding the
shared state-backend fixtures (same seeding step the `.github/workflows/floci-terraform-*.yml`
pipelines do per-run, for the same underlying reason — a CI runner's Floci container starts empty
too). Re-establishing a working `03` cluster on this Floci instance would require re-seeding the state
backend and re-running `03`'s applies from phase 1 through phase 3 — each of those is a real
`terraform apply`, requiring explicit per-run go-ahead same as any other apply, not something to do
as a side effect of a `04` preflight check.

**Not resolved by this phase; needs a decision before phase 1 can proceed**, see open question below.

## Open question (for the user)

`03`'s infrastructure needs to exist on whatever Floci instance `04` will test against, and right now
it doesn't. Options:
1. Re-seed the state-backend fixtures and re-apply `03` (phases 1-3, or at minimum phase 3 if state
   for 1-2 can be skipped) against this Floci instance — real `terraform apply` calls, each needing
   explicit go-ahead.
2. Treat this as a standing Floci limitation and investigate whether Floci supports a persistent data
   volume/snapshot mode (not checked yet) so this doesn't recur every time the container restarts.
3. Defer `04` entirely until real AWS credentials are available, sidestepping Floci's persistence gap
   altogether — bigger change, affects `02`/`03` too, not just `04`.
Recommend option 1 for now (fastest path to an actual KEDA test), with option 2 worth a quick check
since this will otherwise repeat every session.
