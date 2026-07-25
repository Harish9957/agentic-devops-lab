# Phase 2 — Apply

## Goal

Actually create the VPC, subnet, Internet Gateway, and route table in AWS, from the plan reviewed
in phase 1.

## Builds on

Phase 1 (plan reviewed, `tfplan` file exists and matches what was shown).

## Status: APPLIED (against Floci)

Authorized 2026-07-25 ("yes go ahead"), applied against the local Floci emulator (`use_floci=true`),
not real AWS. The real-AWS path is still blocked separately on phase 0's credentials gate — this
completion is scoped to Floci only.

## Steps (as run)

1. `terraform apply tfplan` — applied the exact plan reviewed in phase 1, not a freshly generated one
2. `aws ec2 describe-vpcs --vpc-ids <output.vpc_id>` against the Floci endpoint to confirm state
   independently of Terraform's own report

## Completion gate

- [x] User explicitly authorized this apply (2026-07-25, "yes go ahead", in response to the
      Floci-plan summary — this run only, per the repo-wide gate rule)
- [x] `terraform apply` completed: 5 added, 0 changed, 0 destroyed
- [x] `aws ec2 describe-vpcs` shows the VPC in `available` state (confirmed independently, not just
      Terraform's own output)

## Notes / decisions

Ran `terraform apply tfplan` (the plan file saved in phase 1, generated with
`-var="use_floci=true"`). All 5 resources created against Floci:

- `aws_vpc.main` → `vpc-e705db27`
- `aws_internet_gateway.main` → `igw-0b611cdd`
- `aws_route_table.public` → `rtb-c1f7887f`
- `aws_subnet.public` → `subnet-d7a7dd89`
- `aws_route_table_association.public` → `rtbassoc-0f031f72`

Outputs: `vpc_id = vpc-e705db27`, `public_subnet_id = subnet-d7a7dd89`.

Independently verified via `aws ec2 describe-vpcs --vpc-ids vpc-e705db27` against
`http://localhost:4566` (not just trusting Terraform's own "apply complete" message) — VPC shows
`State: available`, correct CIDR `10.0.0.0/16`, correct `Name` tag.

This state is local-only (Floci container, local Terraform state file) — it doesn't touch real AWS
and isn't billable. Teardown (see `../teardown.md`) still requires its own explicit go-ahead before
`terraform destroy`, same as any other mutating command.
