# Phase 1 — EC2 in the private subnet

## Status: APPLIED (against Floci) — plan reviewed and authorized 2026-07-25

## Goal

Write the Terraform code for an EC2 instance placed in `02-terraform-vpc`'s private subnet
(consumed via `terraform_remote_state`, not a hardcoded ID), and produce a reviewed plan. Nothing
gets created in AWS during this phase.

## Builds on

Phase 0 (terraform + AWS/Floci credentials confirmed; `02`'s remote state confirmed readable).

## Steps

1. `provider.tf` — same provider/backend shape as `02-terraform-vpc` (S3 backend, `use_floci`
   toggle), backend key `03-terraform-app-tier/terraform.tfstate`.
2. `remote_state.tf` — `terraform_remote_state` data source reading `02-terraform-vpc`'s state;
   exposes `data.terraform_remote_state.vpc.outputs.private_subnet_id` etc.
3. `variables.tf` — instance type, AMI (or `data "aws_ami"` lookup), name prefix.
4. `ec2.tf` — `aws_instance` in `data.terraform_remote_state.vpc.outputs.private_subnet_id`. No
   public IP (private subnet has none to assign). Security group allowing only what's actually
   needed (not `0.0.0.0/0` inbound — private subnet has no direct internet route in anyway, only
   outbound via NAT).
5. `outputs.tf` — `ec2_instance_id`.
6. `terraform init` (with backend config), `terraform validate`, `terraform plan -out=tfplan`.

## Completion gate

- [x] `terraform validate` exits 0
- [x] `terraform plan -var="use_floci=true"` shows exactly 2 resources to add
      (`aws_security_group.ec2`, `aws_instance.app`), 0 to change, 0 to destroy
- [x] Plan confirms the instance lands in `subnet-9f7fb509` (`02`'s `private_subnet_id`), not the
      public subnet — read directly from plan output, not assumed
- [x] Plan output has been read and shared, not just run
- [x] User explicitly authorized this apply (2026-07-25, "go ahead")
- [x] `terraform apply` completed: 2 added, 0 changed, 0 destroyed
- [x] Independently confirmed via `aws ec2 describe-instances` against the Floci endpoint — not just
      Terraform's own report

## Notes / decisions

2026-07-25: `data "terraform_remote_state" "vpc"` initially failed `terraform validate` —
"Inconsistent conditional result types" — because the Floci/non-Floci branches of the `config`
ternary had different object attribute sets (Floci branch had extra keys like `access_key`). Fixed
by making each attribute independently conditional (`var.use_floci ? "test" : null`, matching
`provider.tf`'s own pattern) instead of two differently-shaped objects. Validated cleanly after.

`terraform plan -var="use_floci=true"` against Floci: 2 to add, 0 to change, 0 to destroy.
`aws_instance.app` — `t3.small`, `ami-0c101f26f147fa7fd`, `subnet_id = "subnet-9f7fb509"` (confirms
remote state correctly resolved `02`'s `private_subnet_id`), no `associate_public_ip_address` set
(private subnet doesn't assign one). `aws_security_group.ec2` — egress-only (`0.0.0.0/0`), no
ingress rules yet; will be opened up to the ALB's security group specifically once that phase adds
one, rather than opening to a wide CIDR now. Saved to `tfplan`.

**Applied (same day, separate explicit go-ahead — "go ahead"):** ran `terraform apply tfplan`
against Floci. 2 resources created:

- `aws_security_group.ec2` → `sg-cdb148c02b69f89a7`
- `aws_instance.app` → `i-ca49a33bc2265a490`

Outputs: `ec2_instance_id = "i-ca49a33bc2265a490"`, `ec2_private_ip = "172.17.0.4"`.

Independently verified via `aws ec2 describe-instances --instance-ids i-ca49a33bc2265a490
--endpoint-url http://localhost:4566` (test credentials, not just trusting Terraform's own "apply
complete" message): `State: running`, `InstanceType: t3.small`, `SubnetId: subnet-9f7fb509` (`02`'s
actual private subnet). Floci also reports `PublicIp: 127.0.0.1` — this is an artifact of Floci
emulating EC2 instances as local Docker containers (per `02-terraform-vpc`'s own phase 0 notes), not
a real public IP; `associate_public_ip_address` isn't set on the resource and the private subnet
doesn't assign one, so this isn't actually internet-facing.

This state is local-only (Floci container, remote state in Floci's emulated S3) — doesn't touch real
AWS and isn't billable. Teardown (see `../teardown.md`) still requires its own explicit go-ahead
before `terraform destroy`.

**Tags added (same day, separate explicit go-ahead — "yes"):** added `var.environment` (default
`"dev"`) and an `env` tag to both `aws_instance.app` and `aws_security_group.ec2`. Plan showed a
clean in-place update (0 to add, 2 to change, 0 to destroy) — only the `tags`/`tags_all` maps
changed, nothing else. Applied against Floci; independently confirmed via `aws ec2 describe-tags
--filters "Name=resource-id,Values=i-ca49a33bc2265a490"`, showing both `Name` and `env=dev`.
