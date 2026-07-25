# Phase 1 — EC2 in the private subnet

## Goal

Write the Terraform code for an EC2 instance placed in `02-terraform-vpc`'s private subnet
(consumed via `terraform_remote_state`, not a hardcoded ID), and produce a reviewed plan. Nothing
gets created in AWS during this phase.

## Builds on

Phase 0 (terraform + AWS/Floci credentials confirmed; `02`'s remote state confirmed readable).

## Steps

1. `provider.tf` — same provider/backend shape as `02-terraform-vpc` (S3 backend, `use_floci`
   toggle), backend key `03-terraform-app/terraform.tfstate`.
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

- [ ] `terraform validate` exits 0
- [ ] `terraform plan` shows the EC2 instance (and its security group, if new) landing in
      `private_subnet_id`, not `public_subnet_id` — confirmed by reading the plan output, not assumed
- [ ] Plan output has been read and shared, not just run

## Notes / decisions

(Not started.)
