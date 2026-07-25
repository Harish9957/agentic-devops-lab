# Phase 2 — Apply + Migrate

## Goal

Create the S3 bucket + DynamoDB table, then migrate `02-terraform-vpc`'s existing local state into
this backend so its state file is no longer only on disk.

## Builds on

Phase 1 (plan reviewed, `tfplan` exists and matches what was shown).

## BLOCKED

Do not run `terraform apply` for this phase, and do not run `02-terraform-vpc`'s
`terraform init -migrate-state`, until the user explicitly authorizes this specific run — same
rule as every other real-cloud-mutating command in this repo. This file stays unchecked until that
go-ahead is given and recorded below.

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

- [ ] User explicitly authorized this apply (record date/confirmation here when it happens)
- [ ] `terraform apply` completes: 6 added, 0 changed, 0 destroyed
- [ ] `02-terraform-vpc` state migrated: `terraform state list` still shows all 10 resources
      post-migration
- [ ] Locking verified: a DynamoDB item appears in the lock table during an in-progress
      `terraform plan`/`apply`

## Notes / decisions

(Fill in once authorized and run.)
