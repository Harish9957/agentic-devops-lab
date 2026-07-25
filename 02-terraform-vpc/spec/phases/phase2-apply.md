# Phase 2 — Apply

## Goal

Actually create the VPC, subnet, Internet Gateway, and route table in AWS, from the plan reviewed
in phase 1. Extended same-day to add a private subnet + NAT Gateway, per the design rule added to
phase 0 (compute belongs in private subnets, never the public one).

## Builds on

Phase 1 (plan reviewed, `tfplan` file exists and matches what was shown).

## Status: APPLIED in full (against Floci) — base VPC + private subnet/NAT extension

Both the base 5-resource VPC and the private-subnet/NAT extension (5 more resources) are applied,
each authorized separately with its own explicit "yes go ahead" (2026-07-25, both same day). All
against the local Floci emulator (`use_floci=true`), not real AWS. The real-AWS path is still blocked
separately on phase 0's credentials gate.

## Steps (as run)

1. `terraform apply tfplan` — applied the exact plan reviewed in phase 1, not a freshly generated one
2. `aws ec2 describe-vpcs --vpc-ids <output.vpc_id>` against the Floci endpoint to confirm state
   independently of Terraform's own report

## Completion gate — base VPC (5 resources)

- [x] User explicitly authorized this apply (2026-07-25, "yes go ahead", in response to the
      Floci-plan summary — this run only, per the repo-wide gate rule)
- [x] `terraform apply` completed: 5 added, 0 changed, 0 destroyed
- [x] `aws ec2 describe-vpcs` shows the VPC in `available` state (confirmed independently, not just
      Terraform's own output)

## Completion gate — private subnet + NAT Gateway (5 more resources)

- [x] User explicitly authorized this apply (2026-07-25, "yes", a separate go-ahead from the base
      VPC's — not covered by the earlier authorization)
- [x] `terraform apply` completed: 5 added, 0 changed, 0 destroyed
- [x] `aws ec2 describe-subnets` shows the private subnet in `available` state, in AZ `us-east-1b`
      (confirmed independently, not just Terraform's own output)

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

**Private subnet + NAT Gateway extension (same day, second authorized apply):** ran
`terraform apply tfplan` again against the plan reviewed in phase 1's later notes. 5 more resources
created against Floci:

- `aws_subnet.private` → `subnet-9f7fb509` (AZ `us-east-1b`, CIDR `10.0.2.0/24`)
- `aws_eip.nat` → `eipalloc-5acc7197ff779ac42`
- `aws_nat_gateway.main` → `nat-8564af9dd015c7e2f`
- `aws_route_table.private` → `rtb-bd34c82d`
- `aws_route_table_association.private` → `rtbassoc-399eb518`

Outputs updated: `private_subnet_id = subnet-9f7fb509`. Independently verified via
`aws ec2 describe-subnets --subnet-ids subnet-9f7fb509` — `State: available`,
`AvailabilityZone: us-east-1b`, `MapPublicIpOnLaunch: false` (correctly private, unlike the public
subnet). Same local-only, non-billable scope as the base VPC.

**State migrated to remote backend (same day):** state for this use case moved from local
`terraform.tfstate` to the shared S3 bucket + DynamoDB lock table in `../terraform-state-backend/`.
`provider.tf` now has an empty `backend "s3" {}` block (backend blocks can't reference variables, so
the actual config is external); `backend-floci.hcl` supplies the Floci-targeted bucket/key/table plus
endpoint overrides, `backend-aws.hcl.example` is the template for real AWS once credentials exist. Ran
`terraform init -backend-config=backend-floci.hcl -migrate-state`, confirmed the copy prompt. Counted
resources before (10) and after (`terraform state list`, still 10) migrating — nothing lost.
Confirmed the state object genuinely lives in Floci's S3
(`aws s3 ls s3://agentic-devops-lab-tfstate/02-terraform-vpc/`), not just Terraform reporting success.
Verified locking actually functions, not just that the table exists: started a background
`terraform plan` and polled `aws dynamodb scan` on the lock table — a lock item
(`Operation: OperationTypePlan`) appeared mid-plan and was released after. Full details and the
backend's own build/verification: `../terraform-state-backend/spec/phases/phase2-apply.md`.
