# teardown.md

## Before tearing this down

**Check every Terraform use case that might point at this backend first.** Destroying this
bucket/table while `02-terraform-vpc` (or any later use case) still references it in its
`backend.hcl` will strand that use case's state. Migrate dependents back to local state (or point
them at a replacement backend) before running this.

## Steps

1. Confirm no dependent use case's `backend.hcl` still points at this `bucket_name`/
   `dynamodb_table_name` (`grep -r bucket_name */backend.hcl` from repo root, or just check
   `02-terraform-vpc/backend.hcl` directly for now — it's the only dependent so far)
2. `terraform plan -destroy -var="use_floci=true"` — review what would be destroyed first
3. `terraform destroy` — same explicit-go-ahead-every-time rule as any other destroy

## Completion gate

- [ ] No dependent use case's `backend.hcl` references this bucket/table anymore
- [ ] `terraform destroy` completes: 0 remaining resources (`terraform state list` empty)
- [ ] `aws s3 ls` / `aws dynamodb list-tables` confirm the bucket and table are actually gone, not
      just Terraform's own report
