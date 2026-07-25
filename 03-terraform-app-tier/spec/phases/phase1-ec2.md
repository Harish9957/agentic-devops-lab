# Phase 1 — EC2 in the private subnet

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
- [ ] `terraform apply` — **blocked pending explicit go-ahead**, not yet run

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
one, rather than opening to a wide CIDR now. Saved to `tfplan` — not yet applied, needs a separate
explicit go-ahead per this use case's non-negotiable rules.
