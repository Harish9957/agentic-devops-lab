# Phase 3 — EKS + nginx Pod + HPA (replaces phase 2's EC2/ASG approach)

## Status: APPLIED in full (against Floci) — plan reviewed and authorized 2026-07-25; nginx Pod,
Service, and HPA verified end-to-end the same day, with four Floci-specific gaps documented below
(not config defects — see Notes)

## Goal

Run nginx as a Kubernetes Pod (Deployment + Service), not a bare OS process or a hand-rolled
single-node k3s install on an EC2 instance, and scale it with a real HorizontalPodAutoscaler. The
ALB still fronts it, now via a NodePort Service instead of nginx listening directly on the host.

## Builds on

Phase 1 (EC2 applied) and phase 2 (ALB + ASG applied) — but **replaces** the compute layer those
phases built. See phase 2's superseded note for why.

## Why this replaced phase 2's approach

While testing whether Floci's EKS support was worth using (prompted by asking "does Floci support
EKS?" before writing any code), a throwaway probe (separate scratch Terraform config, destroyed
after testing, never committed) showed Floci runs a **real `rancher/k3s` server container** for
"EKS" — not just API-level mocking like the ALB. Confirmed via `docker ps`
(`rancher/k3s:latest`, command `/bin/k3s server --d...`) and `docker inspect` (only port 4566
exposed by the main Floci container, but the EKS cluster gets its own container with the API server
port published). `kubectl get nodes`, deploying a real Deployment/Service/HPA, and `kubectl top
pods` all worked, with `metrics-server` running by default (only `traefik` disabled) — so HPA got
real CPU percentages, not `<unknown>`. This is a fundamentally more solid foundation than bare EC2 +
manually-started k3s, so the architecture switched.

## Steps (as run)

1. Deleted `asg.tf` (launch template, ASG, EC2 security group, `user_data`-installed nginx) — no
   longer needed.
2. `eks.tf` — `aws_iam_role`/`aws_iam_role_policy_attachment` for the cluster and node roles (real
   AWS managed policies: `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`,
   `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`), `aws_eks_cluster.app` (subnets:
   both public + the private one), `aws_eks_node_group.app` (private subnet only, instances typed
   `var.instance_type`), `aws_security_group_rule.nodeport_from_alb` (cluster SG ← ALB SG on
   `var.node_port`), `aws_autoscaling_attachment.app` (node group's own managed ASG → the ALB's
   target group).
3. `kubernetes-provider.tf` — `provider "kubernetes"` authenticated via the same mechanism
   `aws eks get-token` uses manually (`exec` plugin), with the Floci endpoint/credentials override
   applied conditionally on `var.use_floci`, same pattern as the `aws` provider's own config.
4. `k8s-nginx.tf` — `kubernetes_deployment_v1.nginx`, `kubernetes_service_v1.nginx` (NodePort,
   `var.node_port`), `kubernetes_horizontal_pod_autoscaler_v2.nginx` (CPU-utilization target 50%,
   1-4 replicas) — replacing the shell-heredoc-embedded YAML from phase 2's `user_data` with proper
   Terraform-native Kubernetes provider resources.
5. `variables.tf` — removed `ami_id`, `asg_min_size`/`asg_max_size`/`asg_desired_capacity`; added
   `node_group_min_size`/`node_group_max_size`/`node_group_desired_size`. Kept `instance_type`,
   `app_port`, `node_port`.
6. `outputs.tf` — removed `asg_name`/`launch_template_id`; added `eks_cluster_name`,
   `eks_cluster_endpoint`, `node_group_name`. Kept `alb_dns_name`, `target_group_arn`.
7. `provider.tf` — added `eks`/`iam` to the Floci endpoints block (alongside the `elbv2`/
   `autoscaling` added in phase 2); added the `kubernetes` provider to `required_providers`.
8. `terraform init`, `validate`, `plan -var="use_floci=true" -out=tfplan`, `apply`.

## Completion gate

- [x] `terraform validate` exits 0
- [x] `terraform plan` reviewed before every apply in this phase
- [x] User explicitly authorized the applies in this phase (2026-07-25)
- [x] `terraform apply` completed in full: EKS cluster + node group + IAM roles created;
      `kubernetes_deployment_v1`/`kubernetes_service_v1`/`kubernetes_horizontal_pod_autoscaler_v2`
      created; old ASG/launch-template/EC2 security group destroyed
- [x] `kubectl get nodes` shows a `Ready` node; `kubectl get pods` shows nginx `Running`
- [x] HPA reports real CPU metrics (`cpu: 0%/50%`), not `<unknown>` — `metrics-server` confirmed
      actually scraping
- [x] HTTP `200` confirmed via the NodePort, independently of Terraform's own report

## Notes / decisions

**Two ordering/data bugs hit and fixed while applying, distinct from the Floci-specific gaps below:**

1. `aws_lb_target_group.app`'s `port` changed from `80` (still-live from phase 2, before that
   NodePort switch was ever applied) to `30080` — a legitimate replace, not a new bug. But the
   default destroy-before-create ordering tried to delete the old target group while it was still
   attached to the listener, and AWS rejected it: `ResourceInUse: ... in use by a listener or rule`.
   Fixed with `lifecycle { create_before_destroy = true }` on the target group — universally
   correct, not Floci-specific.
2. The EKS cluster's `vpc_config[0].cluster_security_group_id` came back as an **empty string**,
   not `null` — a `count = ... != null ? 1 : 0` guard didn't catch it (empty string `!= null` is
   `true`). Fixed by checking `!= ""` instead. Caught via `terraform console`, not assumed.

**Four Floci-specific gaps found, all documented in code comments where they apply, not silently
worked around:**

1. **`aws_eks_cluster.app.vpc_config[0].cluster_security_group_id` is a blank string on Floci** —
   its "cluster" is a bare k3s container, not real VPC-level security-group-backed infra.
   `aws_security_group_rule.nodeport_from_alb` uses `count` to skip itself when blank; real AWS
   always populates this, so the rule still applies there.
2. **The EKS node group's reported backing ASG isn't real on Floci** —
   `aws_eks_node_group.app.resources[0].autoscaling_groups[0].name` returns a name, but attaching
   it (`aws_autoscaling_attachment.app`) fails: `ValidationError: Auto Scaling group ... not
   found`. Real EKS managed node groups do create a genuine backing ASG (this is the standard,
   correct way to wire an ALB to one) — skipped only for `var.use_floci` via `count`.
3. **Floci's ALB still has no real data-plane** (same gap as phase 2, unchanged by this rewrite) —
   the ALB DNS name won't actually proxy to the NodePort in this emulator, even though target
   registration would (if gap #2 above didn't also block it). Verified reachability one layer down
   instead: `docker exec floci curl http://<node-ip>:30080/` → `200`, from inside Floci's own
   Docker network (the node's bridge IP isn't reachable from a normal host terminal either — same
   Docker-Desktop-on-macOS gap documented in phase 2's notes, applies identically here).
4. **`metrics-server` works, which was the pleasant surprise** — unlike the three gaps above, this
   one is a capability, not a limitation: real CPU metrics, not `<unknown>`, confirmed via
   `kubectl top pods` and the HPA's own reported `TARGETS` column.

**Verification path used, given gaps #2 and #3 above:** `aws eks update-kubeconfig` (with
`--endpoint-url` pointed at Floci) generated a real kubeconfig; `kubectl get nodes/pods/svc/hpa`
against it showed a `Ready` node, `Running` nginx Pod, the `NodePort` Service on `30080`, and the
HPA with live metrics. Found the node's actual container (`docker ps --filter
name=floci-eks-agentic-devops-lab-03-eks`) and its bridge IP, then `docker exec floci curl
http://<ip>:30080/` returned `200` — proving the full Pod → Service → NodePort path works, even
though the ALB itself can't be used to prove it on Floci.
