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

- `terraform version`, `helm version`, `kubectl version --client` all exit 0.
- Floci running (`floci start`) and `var.use_floci = true`, same choice `02`/`03` made — real AWS
  path stays the untested default, consistent with both.
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

- [ ] `terraform version` / `helm version` / `kubectl version --client` all exit 0
- [ ] Floci path confirmed working (same as `02`/`03`); real-AWS path still untested
- [ ] `terraform_remote_state` data source resolves `03`'s `eks_cluster_name`
- [ ] `data "aws_eks_cluster"` resolves a live endpoint + CA cert from that name, against Floci
- [ ] `kubectl get nodes/deployment/svc/hpa` (via a kubeconfig pointed at `03`'s cluster) shows `03`'s
      resources still `Ready`/`Running`/applied, unmodified by this preflight
- [ ] `helm show chart kedacore/keda` resolves; chart version to pin for phase 1 recorded here

## Notes / decisions

Cluster-access pattern decided above (option 2: re-derive via `data "aws_eks_cluster"`, don't add new
outputs to `03`). Everything else in this doc is a template — checks haven't been run yet; this task
was scoped as planning/spec-writing only, no terraform/helm/kubectl commands executed. Results get
filled in here once phase 0 is actually run, same pattern `02`/`03` used (their phase 0 docs were
written once, then updated in place with real findings after running the checks).
