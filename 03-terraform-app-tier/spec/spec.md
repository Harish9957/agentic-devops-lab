# spec.md

## Goal

Build the app-tier AWS resources on top of `02-terraform-vpc`'s network foundation: an EC2 instance
in the private subnet, an Application Load Balancer in the public subnet routing to it, and a
DynamoDB table the instance talks to. These three resources form one cohesive architecture (ALB →
EC2 → DynamoDB) and share a single use case rather than each getting its own numbered folder — see
`CLAUDE.md`'s use-case table for why (numbers mark distinct concepts/milestones, not one per AWS
resource type).

This use case never duplicates `02`'s VPC/subnet resources. It consumes them read-only via a
`terraform_remote_state` data source pointed at the shared backend in `../terraform-state-backend/`.

## Inputs

Variables get added per-phase, alongside the resources that need them (see `variables.tf` once
phase 1 starts writing code) — not pre-declared for phases that haven't started.

## Outputs

Added per-phase as resources are created. Anticipated, not yet real:

| Output | What it is |
|---|---|
| `ec2_instance_id` | ID of the EC2 instance in the private subnet |
| `alb_dns_name` | Public DNS name of the Application Load Balancer |
| `dynamodb_table_name` | Name of the DynamoDB table |

## Non-Negotiable Rules

1. **Phased progression**: same as `01-kind-nginx` / `02-terraform-vpc` — complete phases
   sequentially, confirm each gate before advancing. Only the next phase gets scoped and written;
   don't pre-write the whole roadmap (see `Phases` below).
2. **Plan before apply, always reviewed**: `terraform plan` output gets read and understood before
   any `terraform apply`.
3. **No `apply` or `destroy` without explicit go-ahead, every single time** — repo-wide rule (see
   root `CLAUDE.md`), applies identically here to every resource this use case adds.
4. **Remote state from the start**: unlike `02` (which started local and migrated once solid), this
   use case goes straight to the shared S3 + DynamoDB backend in `../terraform-state-backend/`, key
   `03-terraform-app-tier/terraform.tfstate` — that migration was already learned and verified in `02`, no
   need to relearn it here.
5. **Consume `02`'s outputs via `terraform_remote_state`, never hardcode IDs**: `vpc_id` and
   `private_subnet_id` (and `public_subnet_id` for the ALB) come from a `terraform_remote_state` data
   source reading `02-terraform-vpc`'s state, exactly as `02`'s own spec anticipated for any later
   use case needing its VPC.
6. **Design rule inherited from `02`, still non-negotiable here**: compute goes in the private
   subnet, never the public one. The EC2 instance uses `private_subnet_id`; only the ALB itself
   (internet-facing by nature) uses `public_subnet_id`. DynamoDB is a regional service, not
   VPC-attached, so this rule doesn't apply to it directly — but nothing else this use case adds
   should end up in the public subnet.

## Phases

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm terraform + AWS/Floci
  credentials, confirm `02`'s remote state is actually readable from here
- [`phases/phase1-ec2.md`](./phases/phase1-ec2.md) — EC2 instance in the private subnet, reviewed
  plan (no apply)

Later phases (ALB, DynamoDB) get scoped and added here once phase 1 is solid — don't pre-write them
now.

Teardown is documented separately, not as a phase: [`teardown.md`](./teardown.md).

## Completion Promise

```
✓ Phase 0 — Preflight    PASSED (Floci path; real-AWS path still blocked on credentials)
✓ Phase 1 — EC2 apply    PASSED in full (t3.small in 02's private subnet, applied against Floci,
                         authorized 2026-07-25)

ec2_instance_id: i-ca49a33bc2265a490  (Floci-emulated, not real AWS)
ec2_private_ip:  172.17.0.4           (Floci-emulated, not real AWS)
```
