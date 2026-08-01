# spec.md

## Goal

Install [KEDA](https://keda.sh/) (Kubernetes Event-Driven Autoscaling) onto the EKS cluster
`03-terraform-app-tier` already applied — not a new cluster, not local Kind — and replace `03`'s
manually-defined, CPU-only `kubernetes_horizontal_pod_autoscaler_v2.nginx` with a KEDA
`ScaledObject` targeting the same `nginx` Deployment, driven by KEDA's **cron** scaler.

This gets its own number rather than folding into `03` because it's a genuinely distinct concept —
event-driven/external-metrics autoscaling as a scaling *model*, not another resource bolted onto
`03`'s cohesive ALB → EKS → DynamoDB architecture. Same reasoning root `CLAUDE.md`'s use-case table
gives for why `02` and `03` are separate numbers despite `03` depending entirely on `02`.

**Why cron, not Prometheus or a queue-depth scaler:** KEDA supports dozens of scalers, most of which
need a real external system (Prometheus, SQS, RabbitMQ, etc.) to actually exercise. On Floci, the
only external-system fidelity confirmed so far is EKS itself (`03` verified this empirically — a
real `rancher/k3s` server, real `metrics-server`) — Floci's SQS/CloudWatch/Prometheus support is
untested and not something to assume works. The cron scaler needs no external system at all: it's
purely time-window-based, evaluated entirely inside the KEDA operator. That makes it the scaler
least likely to fail for reasons that have nothing to do with KEDA itself, and the most deterministic
to test (scale up/down at known wall-clock times, no synthetic load generator needed). A
Prometheus-based scaler is a plausible later extension — see `Phases` below — but isn't the starting
point precisely because it stacks an unverified dependency (in-cluster Prometheus on Floci) on top of
an already-unverified one (KEDA on Floci).

**Whether KEDA itself runs cleanly on Floci's k3s-backed EKS is an open question, not an assumption.**
`03` only proved `metrics-server` and core Kubernetes primitives (Deployment/Service/HPA) work
against Floci's EKS. KEDA additionally needs its operator, its admission webhook, and its CRDs
(`ScaledObject`, etc.) to install and reconcile correctly — none of that has been tested against
Floci yet. Phase 1 exists specifically to test this empirically before phase 2 commits to anything
further, same empirical-before-committing approach `03` used before switching to EKS in the first
place. If KEDA doesn't work cleanly on Floci, that's a valid, documented phase-1 outcome, not a
reason to fake success.

This use case never duplicates `03`'s EKS cluster or node group. It consumes `03`'s outputs
read-only via a `terraform_remote_state` data source pointed at the shared backend in
`../terraform-state-backend/` — same inherited pattern `03` used to consume `02`'s VPC outputs.

## Inputs

Variables get added per-phase, alongside the resources that need them (see `variables.tf` once
phase 1 starts writing code) — not pre-declared for phases that haven't started, same approach `03`
took. Two things are already decided, though, because they shape every phase:

- **`use_floci`** (bool, default `false`) — same toggle as `02`/`03`, threaded through this use
  case's own `provider.tf`, `remote_state.tf`, and backend config identically.
- **Cluster reference is a data source, not a variable.** `04` reads `03`'s state for
  `eks_cluster_name` via `terraform_remote_state`, then re-derives live connection details (API
  endpoint, CA certificate, auth token) via its own `data "aws_eks_cluster"` /
  `data "aws_eks_cluster_auth"` lookups keyed on that name — it does not hardcode a cluster ID or
  endpoint, and does not ask `03` to export anything it doesn't already output. See
  `phases/phase0-preflight.md` for the full reasoning.

## Outputs

Added per-phase as resources are created. Anticipated, not yet real:

| Output | What it is |
|---|---|
| `keda_namespace` | Namespace KEDA's operator/webhook/CRDs are installed into |
| `keda_release_name` | Name of the `helm_release` resource installing the KEDA chart |
| `keda_release_version` | Chart version actually installed (pinned, not `latest`) |
| `scaledobject_name` | Name of the KEDA `ScaledObject` targeting `03`'s `nginx` Deployment |
| `managed_hpa_name` | Name of the HPA KEDA auto-generates for the `ScaledObject` (KEDA's own naming convention, typically `keda-hpa-<scaledobject-name>`) — this is the HPA that exists *instead of* `03`'s manual one |

## Non-Negotiable Rules

1. **Phased progression**: same as `01`/`02`/`03` — complete phases sequentially, confirm each gate
   before advancing. Only the next phase gets scoped and written; don't pre-write the whole roadmap.
2. **Plan before apply, always reviewed**: `terraform plan` output gets read and understood before
   any `terraform apply` — applies to `helm_release` and `kubernetes_manifest` resources exactly as
   much as `aws_*` ones. No raw `helm install` or `kubectl apply` CLI shortcuts outside Terraform;
   KEDA is installed via the Terraform `helm` provider's `helm_release` resource, consistent with
   `03` phase 3's move away from shell-heredoc-embedded YAML toward Terraform-native resources.
3. **No `apply` or `destroy` without explicit go-ahead, every single time** — repo-wide rule (see
   root `CLAUDE.md`), applies identically here, including to the HPA removal in rule 5 below.
4. **Consume `03`'s outputs via `terraform_remote_state`, never hardcode IDs**: `eks_cluster_name`
   comes from a `terraform_remote_state` data source reading `03-terraform-app-tier`'s state, exactly
   as `03`'s own spec anticipated for any later use case needing its cluster. Live connection details
   (endpoint, CA cert, auth) are re-derived from that name via `data` sources against the AWS/Floci
   API directly — never duplicated as copy-pasted literals, and never requiring `03` to add new
   outputs just to satisfy `04`.
5. **KEDA supersedes `03`'s HPA — it does not run alongside it, and this requires touching `03`'s
   files.** A KEDA `ScaledObject` generates and manages its own HPA under the hood; a second,
   manually-defined HPA (`03`'s `kubernetes_horizontal_pod_autoscaler_v2.nginx`) targeting the same
   Deployment conflicts with it (`most recent HorizontalPodAutoscaler event` fights, unpredictable
   which one wins). This is the same kind of supersession `03` itself did to `02`'s ASG approach — but
   with a real difference: that supersession was self-contained inside `03`'s own directory, and this
   one is not. Root `CLAUDE.md` says a use case shouldn't require changes outside its own directory —
   this is a deliberate, called-out exception to that convention, not a quiet violation of it. Phase 2
   (once scoped) will delete `03`'s `kubernetes_horizontal_pod_autoscaler_v2.nginx` resource block
   from `03/k8s-nginx.tf` and run `terraform apply` **inside `03`'s own directory** to remove it,
   immediately before applying `04`'s `ScaledObject`. That removal gets its own explicit go-ahead,
   separate from the general apply-gate in rule 3, because it mutates a directory `04` doesn't own.
6. **Floci feasibility is an open question, stated upfront, not assumed away.** The cron scaler was
   chosen specifically because it has zero dependency on any additional emulated AWS service — see
   `Goal` above. Whether KEDA's operator, webhook, and CRDs actually install and reconcile cleanly
   against Floci's k3s-backed EKS control plane is **unverified as of this spec**. Phase 1's entire
   purpose is to test that empirically, the same way `03` tested Floci's EKS fidelity before
   committing to that architecture, rather than assuming a Helm chart that installs cleanly on real
   AWS will behave identically here.
7. **Known Terraform+CRD ordering risk, planned around rather than ignored**: `kubernetes_manifest`
   resources referencing a CRD (like KEDA's `ScaledObject`) generally cannot be reliably planned in
   the same `apply` that installs the CRD via `helm_release` — the provider needs the CRD's schema to
   already be registered in the cluster to plan against it. This is a well-known Terraform/Kubernetes
   provider limitation, not Floci-specific. Phase 1 (install KEDA, no `ScaledObject` yet) and phase 2
   (add the `ScaledObject`) are separate applies specifically to sidestep this, not merged for
   convenience.
8. **KEDA installs into its own namespace** (`keda`), not `default` and not wherever `nginx` lives —
   standard KEDA practice, keeps the autoscaling control plane separate from the workload it scales.

## Phases

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm terraform/helm/kubectl
  access to `03`'s still-applied cluster, confirm `03`'s remote state is readable, confirm the KEDA
  Helm chart itself is reachable
- `phases/phase1-keda-install.md` (not yet written) — install KEDA via `helm_release` into the `keda`
  namespace; verify operator/webhook pods `Running` and CRDs `Established` against Floci; no
  `ScaledObject` yet, `03`'s HPA untouched
- `phases/phase2-scaledobject-cron.md` (not yet written) — add the cron `ScaledObject` for `nginx`;
  remove `03`'s manual HPA (rule 5); verify KEDA's auto-generated HPA appears and replica count
  actually follows the cron schedule's start/end windows

Not committed, possible future extension once phases 1-2 are solid and only if they prove KEDA works
cleanly on Floci: a Prometheus-based or queue-depth scaler as a closer analog to genuinely
event-driven (not just time-scheduled) autoscaling — deliberately deferred, see `Goal` above for why.

Teardown will be documented separately once resources exist (not a phase — same reasoning as `03`'s
`teardown.md`), including the extra step of restoring `03`'s HPA if `04` is torn down independently
of `03`.

## Completion Promise

```
  Phase 0 — Preflight              NOT YET RUN
  Phase 1 — KEDA install           NOT YET SCOPED
  Phase 2 — cron ScaledObject      NOT YET SCOPED

keda_namespace:        (not yet applied)
keda_release_name:     (not yet applied)
keda_release_version:  (not yet applied)
scaledobject_name:     (not yet applied)
managed_hpa_name:      (not yet applied)
```
