# Teardown

## Goal

Destroy all AWS resources created by this use case, cleanly.

## Not a phase

This is a reset/lifecycle operation, not forward progress — same reasoning as
`01-kind-nginx/spec/teardown.md`.

## BLOCKED

Same rule as phase 2: never run `terraform destroy` without the user's explicit go-ahead for that
specific run.

## Steps (once authorized)

1. `terraform plan -destroy` — review what would be destroyed first
2. `terraform destroy` — only after the destroy plan has been reviewed and explicitly approved

## Completion gate

- [ ] User explicitly authorized this destroy
- [ ] `terraform destroy` completes: 0 added, 0 changed, 5 destroyed
- [ ] `aws ec2 describe-vpcs` no longer lists this VPC's ID

## Notes / decisions

(Fill in once authorized and run.)
