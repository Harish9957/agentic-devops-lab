# Phase 1 — Write and Plan

## Goal

Write the VPC Terraform code (`provider.tf`, `variables.tf`, `vpc.tf`, `outputs.tf`) and produce a
reviewed plan. Nothing gets created in AWS during this phase.

## Builds on

Phase 0 (terraform + valid AWS credentials confirmed).

## Steps

1. `terraform init` — downloads the `hashicorp/aws` provider, sets up local state
2. `terraform validate` — syntax/type checking only, no AWS calls
3. `terraform plan -out=tfplan` — shows exactly what would be created; saved to a plan file so
   phase 2 (if/when authorized) applies precisely what was reviewed here, not a freshly recomputed
   plan that could have drifted

## Completion gate

- [x] `terraform validate` exits 0 (confirmed 2026-07-24)
- [ ] `terraform plan` shows exactly 5 resources to add (`aws_vpc`, `aws_subnet`,
      `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`), 0 to change, 0 to
      destroy — blocked on phase 0's AWS credentials gate
- [ ] Plan output has been read and shared, not just run

## Notes / decisions

`terraform init` resolved `hashicorp/aws` to v5.100.0 (constraint `~> 5.0`), no surprises.
`terraform validate` passed cleanly on the first attempt — no syntax/type errors in `provider.tf`,
`variables.tf`, `vpc.tf`, or `outputs.tf`. `terraform plan` cannot complete yet: no AWS credentials
configured on this machine (see phase 0 notes). Revisit once credentials are set up.
