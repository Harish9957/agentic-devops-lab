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
| `asg_name` | Name of the Auto Scaling Group managing the app-tier instances |
| `launch_template_id` | ID of the launch template the ASG uses |
| `alb_dns_name` | Public DNS name of the Application Load Balancer |
| `target_group_arn` | ARN of the ALB target group the ASG registers instances into |
| `dynamodb_table_name` | Name of the DynamoDB table (not yet built) |

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
   subnet, never the public one. The ASG's instances use `private_subnet_id`; only the ALB itself
   (internet-facing by nature) uses `public_subnet_id`. DynamoDB is a regional service, not
   VPC-attached, so this rule doesn't apply to it directly — but nothing else this use case adds
   should end up in the public subnet.
7. **ALB needs 2+ AZs — resolved, not just documented**: `02-terraform-vpc` originally had only one
   public subnet. Confirmed empirically (not just from docs) that even Floci enforces AWS's 2-AZ
   requirement for ALBs — a single-subnet apply genuinely failed. Fixed by adding a second public
   subnet to `02` (`us-east-1c`) — see `02-terraform-vpc/spec/phases/phase2-apply.md` and this use
   case's `phases/phase2-alb-asg.md`.
8. **Floci is a control-plane emulator for ALB/EC2, not a full data-plane one**: `user_data` never
   executes (each instance is a bare container), and the ALB's DNS name doesn't actually proxy
   traffic. Both are Floci-specific limitations, not defects in this use case's Terraform — see
   `phases/phase2-alb-asg.md` Notes for how reachability was verified within what Floci actually
   supports, and what would differ on real AWS.

## Phases

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm terraform + AWS/Floci
  credentials, confirm `02`'s remote state is actually readable from here
- [`phases/phase1-ec2.md`](./phases/phase1-ec2.md) — EC2 instance in the private subnet, applied
- [`phases/phase2-alb-asg.md`](./phases/phase2-alb-asg.md) — EC2 converted to ASG management, ALB
  spanning both public subnets routing to it, nginx running, applied

Later phases (DynamoDB) get scoped and added here once phase 2 is solid — don't pre-write them now.

Teardown is documented separately, not as a phase: [`teardown.md`](./teardown.md).

## Completion Promise

```
✓ Phase 0 — Preflight    PASSED (Floci path; real-AWS path still blocked on credentials)
✓ Phase 1 — EC2 apply    PASSED in full (t3.small in 02's private subnet, applied against Floci,
                         authorized 2026-07-25) — superseded by phase 2's ASG conversion
✓ Phase 2 — ALB+ASG      PASSED in full: ASG + launch template + ALB (2 AZs) + target group +
                         listener applied against Floci, authorized 2026-07-25. nginx running,
                         target healthy, verified end-to-end within Floci's limits (see phase 2
                         notes: Floci doesn't run user_data or proxy ALB traffic — both worked
                         around for verification, both would just work on real AWS)

asg_name:           agentic-devops-lab-03-app-20260725165722293200000003  (Floci-emulated)
alb_dns_name:        app-20260725170316887600000001-e7d0c4d1277748f5.elb.localhost.floci.io (Floci)
target_group_arn:    tg-20260725165722275100000001  (Floci-emulated)
```
