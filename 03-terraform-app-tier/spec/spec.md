# spec.md

## Goal

Build the app-tier AWS resources on top of `02-terraform-vpc`'s network foundation: an EKS cluster
+ node group in the private subnet running nginx as a Kubernetes Pod (Deployment + Service +
HorizontalPodAutoscaler), an Application Load Balancer in the public subnet routing to it, and a
DynamoDB table the app talks to. These form one cohesive architecture (ALB → EKS/nginx → DynamoDB)
and share a single use case rather than each getting its own numbered folder — see `CLAUDE.md`'s
use-case table for why (numbers mark distinct concepts/milestones, not one per AWS resource type).

This started as a bare EC2 instance (phase 1), then EC2 under ASG management (phase 2), then moved
to EKS (phase 3) once testing showed Floci's EKS support has far better fidelity than its EC2/ALB
emulation — a real k3s server, not just API mocking. See `phases/phase2-alb-asg.md`'s superseded
note and `phases/phase3-eks-nginx-hpa.md` for why.

This use case never duplicates `02`'s VPC/subnet resources. It consumes them read-only via a
`terraform_remote_state` data source pointed at the shared backend in `../terraform-state-backend/`.

## Inputs

Variables get added per-phase, alongside the resources that need them (see `variables.tf` once
phase 1 starts writing code) — not pre-declared for phases that haven't started.

## Outputs

Added per-phase as resources are created. Anticipated, not yet real:

| Output | What it is |
|---|---|
| `eks_cluster_name` | Name of the EKS cluster |
| `eks_cluster_endpoint` | Kubernetes API server endpoint for the EKS cluster |
| `node_group_name` | Name of the EKS managed node group running the nginx Pod |
| `alb_dns_name` | Public DNS name of the Application Load Balancer |
| `target_group_arn` | ARN of the ALB target group the node group's instances register into |
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
   subnet, never the public one. The EKS node group's instances use `private_subnet_id`; only the
   ALB itself (internet-facing by nature) uses `public_subnet_id`. DynamoDB is a regional service,
   not VPC-attached, so this rule doesn't apply to it directly — but nothing else this use case adds
   should end up in the public subnet.
7. **ALB needs 2+ AZs — resolved, not just documented**: `02-terraform-vpc` originally had only one
   public subnet. Confirmed empirically (not just from docs) that even Floci enforces AWS's 2-AZ
   requirement for ALBs — a single-subnet apply genuinely failed. Fixed by adding a second public
   subnet to `02` (`us-east-1c`) — see `02-terraform-vpc/spec/phases/phase2-apply.md` and this use
   case's `phases/phase2-alb-asg.md`.
8. **Floci is a control-plane emulator for ALB/EC2, not a full data-plane one — but its EKS support
   is much better**: EC2's `user_data` never executes and the ALB's DNS name doesn't actually proxy
   traffic (both Floci-specific, not defects here — see `phases/phase2-alb-asg.md` Notes). EKS,
   however, runs a genuine `rancher/k3s` server with a real API and `metrics-server` — confirmed
   empirically before committing to it, not assumed. This is why phase 3 moved compute onto EKS: see
   `phases/phase3-eks-nginx-hpa.md` for what still doesn't work there (cluster security group,
   node-group-to-ASG attachment) versus what does (kubectl, Deployments, Services, working HPA).

## Phases

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm terraform + AWS/Floci
  credentials, confirm `02`'s remote state is actually readable from here
- [`phases/phase1-ec2.md`](./phases/phase1-ec2.md) — EC2 instance in the private subnet, applied,
  superseded by phase 3
- [`phases/phase2-alb-asg.md`](./phases/phase2-alb-asg.md) — EC2 converted to ASG management, ALB
  spanning both public subnets, nginx running as an OS process — applied, then superseded by phase 3
- [`phases/phase3-eks-nginx-hpa.md`](./phases/phase3-eks-nginx-hpa.md) — EKS cluster + node group,
  nginx as a Pod (Deployment + Service + HPA), ALB routing to the node group via NodePort, applied

Later phases (DynamoDB) get scoped and added here once phase 3 is solid — don't pre-write them now.

Teardown is documented separately, not as a phase: [`teardown.md`](./teardown.md).

## Completion Promise

```
✓ Phase 0 — Preflight    PASSED (Floci path; real-AWS path still blocked on credentials)
✓ Phase 1 — EC2 apply    PASSED, then superseded by phase 3 (EKS)
✓ Phase 2 — ALB+ASG      PASSED, then superseded by phase 3 (EKS) — see phase 2's superseded note
✓ Phase 3 — EKS+nginx+HPA PASSED in full: EKS cluster + node group + IAM roles applied against
                         Floci (a real k3s server, not just API mocking); nginx Deployment/Service/
                         HPA applied via the Kubernetes provider, authorized 2026-07-25. Node Ready,
                         Pod Running, HPA reporting live CPU metrics, HTTP 200 confirmed via the
                         NodePort. Two Floci-specific gaps skipped for the Floci path only (cluster
                         security group, node-group-ASG attachment) — see phase 3 notes.

eks_cluster_name:     agentic-devops-lab-03-eks       (Floci-emulated, not real AWS)
eks_cluster_endpoint: https://localhost:6501          (Floci-emulated, not real AWS)
node_group_name:      agentic-devops-lab-03-node      (Floci-emulated, not real AWS)
alb_dns_name:         app-20260725170316887600000001-e7d0c4d1277748f5.elb.localhost.floci.io (Floci)
```
