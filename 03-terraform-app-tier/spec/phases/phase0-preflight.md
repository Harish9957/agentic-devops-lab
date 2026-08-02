# Phase 0 — Preflight

## Goal

Confirm Terraform is installed, AWS/Floci credentials work, and — the part specific to this use
case — that `02-terraform-vpc`'s state is actually readable from here via `terraform_remote_state`,
before writing or planning any app-tier resources.

## Builds on

`02-terraform-vpc` phase 2 (VPC + private subnet applied; state migrated to the shared remote
backend) — see its `spec/spec.md` Completion Promise.

## Checks

Run the shared preflight script (same one `02`/`04` use, see `scripts/preflight-check.sh`'s header):

```bash
../scripts/preflight-check.sh --tools "terraform"
```

It checks `terraform version` exits 0, then either real AWS credentials or a reachable Floci
emulator — same choice `02` makes, kept consistent so this use case can target whichever backend
`02` was last applied against. Set `var.use_floci = true` to actually target it.

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

- [x] `terraform version` prints a version (v1.15.1)
- [ ] `aws sts get-caller-identity` succeeds against real AWS — still blocked, no credentials on
      this machine (same as `02-terraform-vpc` phase 0)
- [x] Floci path confirmed working: `floci` container up and healthy at `http://localhost:4566`
- [x] `terraform_remote_state` data source successfully reads `02`'s `vpc_id` (`vpc-e705db27`) and
      `private_subnet_id` (`subnet-9f7fb509`) — confirmed via phase 1's plan output, which resolved
      both correctly from `02`'s remote state

## Notes / decisions

Checked 2026-07-25: `aws sts get-caller-identity` fails with `NoCredentials`, identical to `02`'s
phase 0 finding — real-AWS path stays blocked until credentials are configured. Floci confirmed
already running (`floci` container healthy, 200 response from `http://localhost:4566`), so proceeded
on the Floci path, same choice `02` made. The `terraform_remote_state` check was folded into phase
1's plan run rather than a separate throwaway config — the plan output resolving `subnet_id` and
`vpc_id` to `02`'s actual applied values is direct proof the data source works, no need for a
separate test.
