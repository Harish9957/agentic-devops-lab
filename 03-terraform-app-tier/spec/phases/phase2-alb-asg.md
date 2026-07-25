# Phase 2 — ALB + ASG

## Goal

Put the phase 1 EC2 instance under Auto Scaling Group management (via a launch template) instead
of a standalone `aws_instance`, and front it with an Application Load Balancer in the public subnet.
Nothing gets created/changed in AWS during the plan step of this phase.

## Builds on

Phase 1 (EC2 applied, `aws_instance.app` running). This phase's plan **replaces** that standalone
instance — see Notes below, this is expected and reviewed, not an accident.

## Known gap (documented, not silently worked around)

`02-terraform-vpc` currently has only **one** public subnet (`us-east-1a`). Real AWS requires an
ALB's subnets to span at least two distinct Availability Zones — `aws_lb.app` with a single subnet
will be rejected by the real AWS API. This phase is verified against Floci only (which doesn't
enforce the constraint). Fixing this for real AWS means adding a second public subnet to
`02-terraform-vpc` — out of scope for this phase, tracked here as a known follow-up.

## Steps

1. `asg.tf` (renamed from `ec2.tf`) — `aws_launch_template.app` replaces the standalone
   `aws_instance.app`; `aws_autoscaling_group.app` launches instances from it into the private
   subnet, registered into the ALB's target group. `aws_security_group.ec2` gains an ingress rule
   scoped to the ALB's security group only (not a wide CIDR).
2. `alb.tf` — `aws_security_group.alb` (port `var.app_port` open to `0.0.0.0/0`, it's meant to be
   internet-facing), `aws_lb.app` in the public subnet, `aws_lb_target_group.app` (instance target
   type, health check on `/`), `aws_lb_listener.app` forwarding to the target group.
3. New variables: `app_port` (default `80`), `asg_min_size`/`asg_max_size`/`asg_desired_capacity`
   (defaults `1`/`2`/`1` — same single-instance footprint as phase 1, with headroom to scale later).
4. `outputs.tf` replaces `ec2_instance_id`/`ec2_private_ip` (meaningless once instances are
   ASG-managed and can churn) with `asg_name`, `launch_template_id`, `alb_dns_name`,
   `target_group_arn`.
5. `terraform validate`, `terraform plan -var="use_floci=true" -out=tfplan`.

## Completion gate

- [x] `terraform validate` exits 0
- [x] `terraform plan -var="use_floci=true"` shows 6 to add (ASG, launch template, ALB, listener,
      target group, ALB security group), 1 to change (EC2 security group ingress), 1 to destroy
      (old standalone `aws_instance.app`) — reviewed and understood, not just run
- [x] Plan confirms the ALB lands in the public subnet (`subnet-d7a7dd89`), ASG in the private
      subnet (`subnet-9f7fb509`) — design rule upheld
- [ ] `terraform apply` — **blocked pending explicit go-ahead**, not yet run

## Notes / decisions

2026-07-25: user asked for an ALB in the public subnet and an ASG to manage the phase-1 EC2
instance. Flagged the ALB's real-AWS two-AZ requirement before writing any code, since
`02-terraform-vpc` only has one public subnet — user chose to proceed Floci-only and document the
gap rather than extend `02` right now (see Known Gap above).

Converting phase 1's standalone `aws_instance.app` to ASG management is a genuine replace, not an
in-place change: Terraform destroys the old instance (`i-ca49a33bc2265a490`) and the ASG launches a
new one from the launch template. This is visible directly in the plan diff, reviewed before any
apply — not hidden or minimized.

`aws_lb`/`aws_lb_target_group` `name_prefix` has an AWS-enforced 6-character max (an easy-to-miss
restriction, unlike the 32-char `name` field) — used short fixed prefixes (`"app-"`, `"tg-"`) rather
than deriving from `var.name`, which could exceed the limit or contain awkward characters.
