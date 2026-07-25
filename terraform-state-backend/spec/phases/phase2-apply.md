# Phase 2 — Apply + Migrate

## Goal

Create the S3 bucket + DynamoDB table, then migrate `02-terraform-vpc`'s existing local state into
this backend so its state file is no longer only on disk.

## Builds on

Phase 1 (plan reviewed, `tfplan` exists and matches what was shown).

## Status: APPLIED + migrated (against Floci)

Authorized 2026-07-25 ("yes"). Applied against the local Floci emulator, then migrated
`02-terraform-vpc`'s state into it. Real AWS is unaffected and still blocked on phase 0's credentials
gate — this completion is scoped to Floci only.

## Steps (once authorized)

1. `terraform apply tfplan` (in this directory) — creates the bucket + table
2. In `02-terraform-vpc`: add a `backend "s3" {}` block to `provider.tf` and a `backend.hcl` file
   with this backend's `bucket_name`/`dynamodb_table_name` outputs (plus the Floci endpoint overrides
   when `use_floci=true`, since backend blocks can't reference variables)
3. `terraform init -backend-config=backend.hcl -migrate-state` (in `02-terraform-vpc`) — Terraform
   prompts to confirm copying existing state into the new backend; the old local `terraform.tfstate`
   is kept as a `.backup` file, not deleted
4. Confirm: `terraform state list` in `02-terraform-vpc` still shows all 10 resources after migration,
   and a lock actually shows up in the DynamoDB table during a `terraform plan` run (proves locking
   works, not just that the table exists)

## Completion gate

- [x] User explicitly authorized this apply (2026-07-25, "yes")
- [x] `terraform apply` completed: 6 added, 0 changed, 0 destroyed
- [x] `02-terraform-vpc` state migrated: `terraform state list` shows all 10 resources post-migration
- [x] Locking verified: a DynamoDB item appeared in the lock table during an in-progress
      `terraform plan`, released after it completed

## Notes / decisions

Ran `terraform apply tfplan` — all 6 resources created against Floci (`aws_s3_bucket`,
`aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`,
`aws_s3_bucket_public_access_block`, `aws_s3_bucket_policy`, `aws_dynamodb_table`). Independently
verified (not just Terraform's own report): `aws s3api get-bucket-versioning` → `Enabled`,
`aws s3api get-bucket-encryption` → `AES256`, `aws dynamodb describe-table` → `ACTIVE`,
`PAY_PER_REQUEST`, hash key `LockID`.

**Migration:** counted `02-terraform-vpc`'s local state directly before migrating (`terraform.tfstate`
had exactly 10 resources: vpc, both subnets, both route tables, both route table associations, igw,
nat gateway, eip). Added `backend "s3" {}` to `02-terraform-vpc/provider.tf` (empty — backend blocks
can't reference variables, so the actual bucket/key/table/Floci-endpoint values live in
`02-terraform-vpc/backend-floci.hcl`, supplied via `-backend-config`). Ran
`terraform init -backend-config=backend-floci.hcl -migrate-state`, answered "yes" to the copy-state
prompt. `terraform state list` afterward shows the same 10 resources. Local `terraform.tfstate` is now
empty (Terraform manages it remotely); the pre-migration content is preserved in
`terraform.tfstate.backup` (gitignored, local only — not a substitute for the real state, just
Terraform's own safety net).

Confirmed the state is genuinely remote, not just locally reported as such: `aws s3 ls
s3://agentic-devops-lab-tfstate/02-terraform-vpc/` shows the state object in Floci's S3.

**Locking:** started `terraform plan` in the background and polled `aws dynamodb scan` on the lock
table every 0.3s. Mid-plan, a `LockID = agentic-devops-lab-tfstate/02-terraform-vpc/terraform.tfstate`
item appeared with `Operation: OperationTypePlan`, `Who: harish@...`, a timestamp — then disappeared
once the plan finished. This is a real lock cycle, not just an empty table that happens to exist.
The plan itself reported "No changes" — migrated state matches real infrastructure exactly.

**Caveat noticed, not acted on:** `terraform init` printed a deprecation warning —
`dynamodb_table` is deprecated in favor of `use_lockfile` (S3-native locking, no DynamoDB table
needed, available since Terraform ~1.10). Kept `dynamodb_table` deliberately since that's what was
explicitly asked for and it's still the most widely supported/understood pattern (works on any
Terraform version, well understood by LocalStack/Floci-style emulators); worth revisiting if a later
use case wants to drop the DynamoDB table entirely.
