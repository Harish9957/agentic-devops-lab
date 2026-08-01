# Phase 4 — DynamoDB

## Status: NOT STARTED — planning only, no `.tf` files touched yet, no `apply`

## Goal

Create the DynamoDB table itself and an IAM policy granting the EKS node group's role access to
it. This phase does **not** wire nginx to DynamoDB — nginx serves static content and has no natural
reason to call a database. Faking that integration would violate this repo's writing standard
("direct and declarative, no filler"). What this phase actually delivers: the table exists, is
reachable from inside the cluster (IAM-wise), and is ready for a real application to use. Exercising
it end-to-end (a Pod that actually reads/writes an item) requires a follow-on app change — swapping
nginx for something with real logic, or adding a sidecar/init container that does a scripted
put-item/get-item as a smoke test. That follow-on is out of scope here and not committed to yet; see
Open questions below.

## Builds on

Phase 3 (EKS cluster + node group applied, `aws_iam_role.eks_node` exists in `eks.tf`) — the new
IAM policy attaches to that same role, no new role created.

## Naming clash to keep straight

`../terraform-state-backend/` already has a `DynamoDB` table
(`agentic-devops-lab-tflocks`, `var.dynamodb_table_name` there) — but that one is Terraform's own
state-locking table for this use case's remote backend, unrelated to application data. The table
this phase creates is a second, independent DynamoDB table, for the app tier's own use, in the same
AWS account/region but with no relationship to state locking. Don't confuse the two when reading
`aws dynamodb list-tables` output later — both will be present.

## Planned steps

1. `dynamodb.tf` — new file, `aws_dynamodb_table.app`:
   - `billing_mode = "PAY_PER_REQUEST"` (on-demand — no capacity planning needed for a lab table
     with negligible, unpredictable traffic; avoids paying for provisioned throughput that mostly
     sits idle).
   - Single-attribute hash key, no range key, until a concrete access pattern says otherwise (see
     Open questions).
   - Tagged consistently with every other resource in this use case (`Name`, `env = var.environment`).
2. `dynamodb.tf` (same file) — `aws_iam_policy.dynamodb_app_access`: least-privilege document scoped
   to `dynamodb:GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`, `Scan` on the one table's
   ARN only (`aws_dynamodb_table.app.arn`, plus `${aws_dynamodb_table.app.arn}/index/*` if a GSI
   gets added later) — not a wildcard `dynamodb:*` or `Resource = "*"`.
3. `dynamodb.tf` (same file) — `aws_iam_role_policy_attachment.eks_node_dynamodb`: attaches the new
   policy to the existing `aws_iam_role.eks_node` (the node group's instance role, defined in
   `eks.tf`). This grants any Pod running on the node group's EC2 instances DynamoDB access via the
   node's instance profile — the same coarse-grained model phase 3's node role already uses for ECR/
   CNI/worker permissions. Not IRSA (IAM Roles for Service Accounts) — this use case doesn't have an
   OIDC provider set up for the cluster, and adding one just for this table would be
   disproportionate. Documented here as a deliberate scope cut, not an oversight — see Open
   questions.
4. `variables.tf` — add:
   - `dynamodb_table_name` (`string`, default something like `"agentic-devops-lab-03-app"` — distinct
     from the state-backend's `agentic-devops-lab-tflocks`, per the naming-clash note above).
   - `dynamodb_hash_key` (`string`, default `"id"` — placeholder until a real access pattern is
     defined, see Open questions).
5. `outputs.tf` — add:
   - `dynamodb_table_name` — already anticipated in `spec.md`'s Outputs table (currently annotated
     "not yet built").
   - `dynamodb_table_arn` — needed by anything (this use case or a later one) that wants to attach
     its own IAM policy to the table without re-deriving the ARN.
6. `provider.tf` — add `dynamodb = "http://localhost:4566"` to the existing Floci `endpoints` block
   (alongside `ec2`/`elbv2`/`autoscaling`/`eks`/`iam` added in phases 2-3), conditional on
   `var.use_floci` exactly like the others.
7. `terraform init` (only if the provider block changed enough to need it), `validate`,
   `plan -var="use_floci=true" -out=tfplan` (or the real-AWS var file, whichever path is live at
   apply time) — reviewed before any `apply`.
8. `terraform apply` — **only with explicit per-run go-ahead**, per root `CLAUDE.md`'s safety rule
   and this use case's `spec.md` rule 3. Not run as part of writing this doc.

## Completion gate

- [ ] `terraform validate` exits 0
- [ ] `terraform plan` reviewed before any apply in this phase
- [ ] User explicitly authorized the apply for this phase (record the date here once it happens)
- [ ] `terraform apply` completed: `aws_dynamodb_table.app`, `aws_iam_policy.dynamodb_app_access`,
      `aws_iam_role_policy_attachment.eks_node_dynamodb` created
- [ ] `aws dynamodb describe-table --table-name <dynamodb_table_name>` (or the Floci-endpoint
      equivalent) reports `ACTIVE`, independently of Terraform's own report
- [ ] IAM policy verified attached to `aws_iam_role.eks_node` (`aws iam list-attached-role-policies`)
- [ ] `dynamodb_table_name` and `dynamodb_table_arn` outputs populated, `spec.md`'s Outputs table
      updated from "not yet built" to real values
- [ ] Explicitly confirm no Pod on the cluster actually calls DynamoDB yet — this phase proves
      reachability/permissions only, not a working data path. Don't mark this gate complete based on
      IAM/table existence alone if a later edit of this doc tries to quietly imply otherwise.

## Open questions (for the user, before implementation)

1. **Access pattern / schema**: what is the table actually for? A hash key of `"id"` is a
   placeholder, not a design — it drives whether a range key is needed, whether a GSI is needed, and
   what `dynamodb:Query` vs `dynamodb:Scan` permissions actually get exercised. Needs a real answer
   before `dynamodb.tf` is written, not just before `apply`.
2. **Does this phase get a real consumer?** Options, roughly increasing in scope:
   - (a) Table + IAM only, as scoped above — proves the infra, no runtime data path. Cheapest, but
     the table sits unused.
   - (b) Add a minimal init container or CronJob to the existing nginx Deployment that does a
     scripted `put-item`/`get-item` on startup, just to prove the IAM-to-data path actually works end
     to end (something more concrete than `describe-table` returning `ACTIVE`).
   - (c) Replace nginx with (or add alongside it) a small app that actually serves DynamoDB-backed
     content — a real architecture change, not a phase-4-sized task.
   Recommend (a) for this phase's `apply`, with (b) as a fast follow if end-to-end proof matters more
   than table existence. (c) is a different use case's worth of work, not phase 4.
3. **IRSA vs node-role IAM**: attaching the DynamoDB policy to the shared node IAM role (as scoped
   above) means *every* Pod on the node group can reach the table, not just a specific
   ServiceAccount. Fine for a lab with one workload; wrong for anything with multiple untrusted
   workloads on the same node group. Flagging so it's a deliberate choice, not a default nobody
   looked at.
4. **Real AWS vs Floci for this phase**: same open question phase 0 left unresolved — real AWS
   credentials are still unavailable on this machine, so this phase (like 1-3) will apply against
   Floci unless that changes. Floci's DynamoDB support hasn't been spot-checked yet the way EKS was
   in phase 3 — worth a quick `aws dynamodb` sanity check against Floci before committing the plan,
   the same empirical-check discipline phase 3 used for EKS rather than assuming LocalStack-compatible
   DynamoDB "just works."

## Notes / decisions

(left blank until this phase is actually applied — see phase 3 for the pattern this section follows)
