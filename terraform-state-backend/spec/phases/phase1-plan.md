# Phase 1 — Write and Plan

## Goal

Write the state backend Terraform code (`provider.tf`, `variables.tf`, `main.tf`, `outputs.tf`) and
produce a reviewed plan. Nothing gets created in AWS/Floci during this phase.

## Builds on

Phase 0 (terraform + Floci/AWS confirmed).

## Steps

1. `terraform init` — downloads the `hashicorp/aws` provider, sets up local state (this directory's
   own state stays local — see spec.md rule 3, chicken-and-egg)
2. `terraform validate` — syntax/type checking only
3. `terraform plan -var="use_floci=true" -out=tfplan` — shows exactly what would be created

## Completion gate

- [x] `terraform validate` exits 0 (confirmed 2026-07-25)
- [x] `terraform plan -var="use_floci=true"` shows exactly 6 resources to add (`aws_s3_bucket`,
      `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`,
      `aws_s3_bucket_public_access_block`, `aws_s3_bucket_policy`, `aws_dynamodb_table`), 0 to change,
      0 to destroy (confirmed 2026-07-25, against Floci)
- [x] Plan output has been read and shared, not just run

## Notes / decisions

`terraform init` resolved `hashicorp/aws` to v5.100.0, same as `02-terraform-vpc`. `terraform
validate` passed cleanly first try. `terraform plan -var="use_floci=true"` against Floci confirms it
supports S3 (bucket, versioning, SSE config, public access block, bucket policy) and DynamoDB
on-demand tables — verified empirically, not assumed, same pattern as `02`'s VPC verification. Saved
to `tfplan`, not yet applied.
