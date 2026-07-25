# Teardown

## Goal

Destroy all AWS resources created by this use case, cleanly.

## Not a phase

This is a reset/lifecycle operation, not forward progress — same reasoning as
`01-kind-nginx/spec/teardown.md` and `02-terraform-vpc/spec/teardown.md`.

## Status: DESTROYED (against Floci) — 2026-07-25

## BLOCKED (applies again next time — this authorization was for one specific run only)

Same rule as every apply in this use case: never run `terraform destroy` without the user's
explicit go-ahead for that specific run.

## Steps (as run)

1. `terraform plan -destroy -var="use_floci=true" -out=destroy.tfplan` — reviewed: 15 resources
   (EKS cluster, node group, 2 IAM roles + 4 policy attachments, ALB + listener + target group +
   ALB security group, 3 Kubernetes resources), 0 to add, 0 to change
2. `terraform apply destroy.tfplan` — only after the destroy plan was reviewed and explicitly
   approved ("yes")

## Completion gate

- [x] User explicitly authorized this destroy (2026-07-25, "yes")
- [x] `terraform destroy` completed: 0 added, 0 changed, 15 destroyed
- [x] Independently confirmed: `terraform state list` empty, `docker ps -a --filter
      name=floci-eks` shows no lingering containers — not just Terraform's own report

## Notes / decisions

2026-07-25: destroyed everything phase 3 (`phases/phase3-eks-nginx-hpa.md`) built — EKS cluster,
node group, IAM roles, ALB stack, and the Kubernetes Deployment/Service/HPA. All against Floci, not
real AWS, not billable. `02-terraform-vpc` untouched — this teardown only affects `03`'s own
resources. `destroy.tfplan` is gitignored (matches `tfplan`'s pattern), not committed.

To rebuild from scratch: `terraform apply` against the current `.tf` files reproduces the same
architecture (phase 1 and 2's EC2/ASG code no longer exists — deleted when phase 3 replaced it, see
phase 2's superseded note), so a fresh apply goes straight to EKS + nginx Pod + HPA, no intermediate
EC2 detour needed.
