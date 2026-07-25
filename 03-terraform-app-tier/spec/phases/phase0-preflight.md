# Phase 0 — Preflight

## Goal

Confirm Terraform is installed, AWS/Floci credentials work, and — the part specific to this use
case — that `02-terraform-vpc`'s state is actually readable from here via `terraform_remote_state`,
before writing or planning any app-tier resources.

## Builds on

`02-terraform-vpc` phase 2 (VPC + private subnet applied; state migrated to the shared remote
backend) — see its `spec/spec.md` Completion Promise.

## Checks

- `terraform version` exits 0
- Either: `aws sts get-caller-identity` exits 0 against real AWS, **or**: a local
  [Floci](https://floci.io/) emulator is running (`floci start`) and `var.use_floci = true` is set —
  same choice `02` makes, kept consistent so this use case can target whichever backend `02` was last
  applied against.
- A minimal `terraform_remote_state` data source reading
  `s3://agentic-devops-lab-tfstate/02-terraform-vpc/terraform.tfstate` resolves and exposes
  `vpc_id`, `public_subnet_id`, `private_subnet_id` — proves this use case can actually consume `02`'s
  outputs before any real resource code depends on them.

## Design rules (non-negotiable, apply to every phase in this use case)

Same compute-goes-in-private-subnet rule as `02-terraform-vpc` phase 0, restated here because this is
where it actually gets exercised: the EC2 instance (phase 1) uses `private_subnet_id`. Only the ALB
(future phase) is internet-facing and uses `public_subnet_id`. DynamoDB (future phase) is regional,
not subnet-attached.

## Completion gate

- [ ] `terraform version` prints a version
- [ ] `aws sts get-caller-identity` succeeds against real AWS, **or** Floci path confirmed working
- [ ] `terraform_remote_state` data source successfully reads `02`'s `vpc_id`,
      `public_subnet_id`, `private_subnet_id`

## Notes / decisions

(Fill in once run.)
