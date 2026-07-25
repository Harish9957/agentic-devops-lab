# Phase 2 — ALB + ASG

## Status: APPLIED in full (against Floci) — plan reviewed and authorized 2026-07-25; nginx added
and end-to-end reachability verified the same day, with two Floci-specific limitations documented
below (not config defects — see Notes)

## Goal

Put the phase 1 EC2 instance under Auto Scaling Group management (via a launch template) instead
of a standalone `aws_instance`, front it with an Application Load Balancer in the public subnet, and
run nginx on the instance so hitting the ALB reaches it.

## Builds on

Phase 1 (EC2 applied, `aws_instance.app` running). This phase's plan **replaced** that standalone
instance — see Notes below, this was expected and reviewed, not an accident.

## Steps (as run)

1. `asg.tf` (renamed from `ec2.tf`) — `aws_launch_template.app` (with `user_data` installing and
   starting nginx) replaces the standalone `aws_instance.app`; `aws_autoscaling_group.app` launches
   instances from it into the private subnet, registered into the ALB's target group.
   `aws_security_group.ec2` gains an ingress rule scoped to the ALB's security group only, on
   `var.app_port` (not a wide CIDR).
2. `alb.tf` — `aws_security_group.alb` (port `var.app_port` open to `0.0.0.0/0`, it's meant to be
   internet-facing), `aws_lb.app` spanning both of `02`'s public subnets, `aws_lb_target_group.app`
   (instance target type, health check on `/`), `aws_lb_listener.app` forwarding to the target group.
3. New variables: `app_port` (default `80`), `asg_min_size`/`asg_max_size`/`asg_desired_capacity`
   (defaults `1`/`2`/`1`).
4. `outputs.tf` replaces `ec2_instance_id`/`ec2_private_ip` (meaningless once instances are
   ASG-managed and can churn) with `asg_name`, `launch_template_id`, `alb_dns_name`,
   `target_group_arn`.
5. `provider.tf` — Floci's `endpoints` block needed `elbv2` and `autoscaling` added alongside `ec2`;
   without them those API calls went to real AWS with fake test credentials and failed with
   `InvalidClientTokenId` (caught on the first apply attempt, fixed before retrying).
6. `terraform validate`, `terraform plan -var="use_floci=true" -out=tfplan`, `terraform apply`.

## Completion gate

- [x] `terraform validate` exits 0
- [x] `terraform plan -var="use_floci=true"` reviewed before every apply in this phase
- [x] Plan confirmed the ALB lands in the public subnets, ASG in the private subnet — design rule
      upheld
- [x] User explicitly authorized each apply in this phase (2026-07-25)
- [x] `terraform apply` completed in full: ASG, launch template, ALB (2 AZs), listener, target
      group, ALB security group all created; EC2 security group updated; old standalone instance
      destroyed
- [x] Target group reports the ASG's instance `healthy` (after manually starting nginx — see Notes)
- [x] Confirmed nginx actually serves `200 OK`, independently of Terraform's own report

## Notes / decisions

2026-07-25: user asked for an ALB in the public subnet, an ASG to manage the phase-1 EC2 instance,
and nginx running on it so hitting the ALB reaches nginx.

**AZ blocker, hit for real, not just assumed:** flagged before writing code that `02-terraform-vpc`
only had one public subnet, and real AWS requires an ALB to span 2+ AZs. User chose to proceed on
Floci first. The first `apply` attempt then genuinely failed against Floci itself —
`InvalidConfigurationRequest: Application Load Balancers must be attached to subnets in at least two
Availability Zones` — proving Floci enforces this constraint too, contrary to the earlier assumption
that it wouldn't. Fixed by adding a second public subnet to `02-terraform-vpc`
(`aws_subnet.public_b`, `us-east-1c`) — see `02-terraform-vpc/spec/phases/phase2-apply.md` for that
change — then pointing `aws_lb.app`'s `subnets` at `02`'s new `public_subnet_ids` output (list of
both) instead of the old singular `public_subnet_id`.

**Provider endpoint gap, also hit for real:** the first apply attempt also failed with
`InvalidClientTokenId` on `aws_lb`/`aws_lb_target_group` reads — `provider.tf`'s Floci `endpoints`
block only routed `ec2` to `http://localhost:4566`, so ELBv2 and Auto Scaling API calls fell through
to real AWS with fake `test`/`test` credentials and were rejected there. Added `elbv2` and
`autoscaling` to the endpoints block; fixed on the next attempt. No orphaned resources were left in
Floci from the failed attempt — checked directly with `aws elbv2 describe-load-balancers` /
`describe-target-groups` before retrying.

**Converting phase 1's standalone instance to ASG management was a genuine replace**, not an
in-place change: Terraform destroyed the old instance (`i-ca49a33bc2265a490`) and the ASG launched a
new one (`i-58e312ea4983f2249`) from the launch template. Visible directly in the plan diff, reviewed
before applying — not hidden or minimized.

**Floci limitation #1 — `user_data` is never executed.** Each Floci "EC2 instance" is a bare
`amazonlinux:2023` Docker container running `tail -f /dev/null` — confirmed via `docker ps` /
`docker inspect`. The launch template's `user_data` (install + start nginx) never ran. Had to
`docker exec` into the instance's container (`floci-ec2-i-58e312ea4983f2249`) and start nginx by
hand for the health check to pass. **This is Floci-specific — on real AWS, `user_data` runs
automatically at boot, no manual step needed.** If this ASG scales or the instance is replaced while
still on Floci, nginx won't come back automatically; it would on real AWS.

**Floci limitation #2 — no real ALB data-plane / traffic forwarding.** The ALB's control plane works
correctly: `aws elbv2 describe-load-balancers` shows `State: active` spanning `us-east-1a` and
`us-east-1c`; `describe-target-health` correctly reported the instance `unhealthy` before nginx was
started and `healthy` after. But the ALB's DNS name
(`app-....elb.localhost.floci.io`) resolves to `127.0.0.1` with nothing actually listening —
confirmed `docker inspect floci` only exposes port `4566`, no dedicated ALB proxy port, and a direct
`curl` to the DNS name gets `Connection refused`. Floci emulates the ALB API surface, not its data
plane. Reachability was instead verified at the layer Floci actually implements: nginx serving `200
OK` on the instance's private IP (`172.17.0.4:80`) from inside Floci's own Docker network, and the
target group correctly reporting that instance healthy — i.e., every piece of AWS-side wiring
(security groups, target registration, health checks) is correct and would carry real traffic
end-to-end on real AWS; only Floci's own proxy is missing.

**Floci limitation #3 — the instance's bridge IP isn't reachable from the host at all, on this
machine.** This runs under Docker Desktop on macOS (confirmed via `docker context ls` /
`docker info`): Docker Desktop puts containers inside a Linux VM, and the Mac host has no route to
the internal bridge network (`172.17.0.0/16`) — only explicitly published ports reach the host.
`docker port floci-ec2-i-58e312ea4983f2249` shows only `22/tcp -> 2200`, nothing for port 80. So
`curl http://172.17.0.4:80/` **fails from a normal host terminal** — confirmed when re-tested from
one — and would fail regardless of whether nginx is running. The only successful verification
(`200 OK`) was `docker exec floci curl http://172.17.0.4:80/`, run *inside* the `floci` container
itself, which sits on that same internal bridge network and can reach other containers by IP
directly. Anyone re-verifying this later needs to use that same `docker exec` approach, or the
target-group health-check API — not a plain host-terminal `curl`.
