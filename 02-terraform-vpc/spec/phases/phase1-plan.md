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
   plan that could have drifted. Against real AWS this needs no flags; against Floci, add
   `-var="use_floci=true"` (see phase 0 notes).

## Completion gate

- [x] `terraform validate` exits 0 (confirmed 2026-07-24)
- [x] `terraform plan -var="use_floci=true"` shows exactly 5 resources to add (`aws_vpc`,
      `aws_subnet`, `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`), 0 to
      change, 0 to destroy (confirmed 2026-07-25, against Floci)
- [ ] Same plan against real AWS (`use_floci=false`) — still blocked on phase 0's AWS credentials gate
- [x] Plan output has been read and shared, not just run

## Notes / decisions

`terraform init` resolved `hashicorp/aws` to v5.100.0 (constraint `~> 5.0`), no surprises.
`terraform validate` passed cleanly on the first attempt — no syntax/type errors in `provider.tf`,
`variables.tf`, `vpc.tf`, or `outputs.tf`.

2026-07-24: `terraform plan` against real AWS cannot complete — no AWS credentials configured on
this machine (see phase 0 notes). Revisit once credentials are set up.

2026-07-25: `terraform plan -var="use_floci=true"` against a local Floci emulator succeeds cleanly —
exactly the 5 expected resources, 0 to change, 0 to destroy, saved to `tfplan`. This is the plan
phase 2 would apply if/when authorized for the Floci path. Note `tfplan` is gitignored and specific
to whichever backend (`use_floci` true/false) it was generated against — regenerate before applying
if the toggle changes.
