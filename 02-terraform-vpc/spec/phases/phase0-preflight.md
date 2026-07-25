# Phase 0 — Preflight

## Goal

Confirm Terraform is installed and AWS credentials are configured and actually valid, before
writing or planning anything.

## Builds on

Nothing — first phase of this use case.

## Checks

- `terraform version` exits 0
- Either: `aws sts get-caller-identity` exits 0 against real AWS, **or**: a local
  [Floci](https://floci.io/) emulator is running (`floci start`) and `var.use_floci = true` is set,
  so `terraform plan`/`apply` target `http://localhost:4566` instead of real AWS. Floci is the
  faster path for iterating on this use case without needing real AWS credentials or spending money;
  real AWS remains the default (`use_floci = false`) for whenever credentials are configured.

## Completion gate

- [x] `terraform version` prints a version (v1.15.1 — a newer 1.15.8 is available but not required)
- [ ] `aws sts get-caller-identity` succeeds and shows the expected Account ID (still open — real AWS
      credentials not configured on this machine)
- [x] Floci path confirmed working: `floci start` brings up the emulator at `http://localhost:4566`;
      `terraform plan -var="use_floci=true"` succeeds (see phase 1 notes)

## Notes / decisions

Checked 2026-07-24: `aws sts get-caller-identity` fails with `NoCredentials` — no AWS credentials
configured on this machine yet. Confirmed this is the actual blocker (not just an untested
assumption) by also running `terraform plan`, which failed the same way: `No valid credential
sources found` / `no EC2 IMDS role found`. Real-AWS path stays open until credentials are configured.

Checked 2026-07-25: added [Floci](https://floci.io/) as an alternative local emulator path so this
use case isn't blocked on real AWS credentials. Installed via `brew install floci-io/floci/floci`,
started with `floci start` (pulls `floci/floci:latest`, serves on `http://localhost:4566`, fake
credentials `test`/`test`). `provider.tf` now has a `use_floci` variable (default `false`, so real
AWS stays the unchanged default) that swaps in `endpoints { ec2 = "http://localhost:4566" }` plus
`skip_credentials_validation`/`skip_metadata_api_check`/`skip_requesting_account_id` when true.
Floci's own docs don't explicitly document VPC/EC2-networking coverage (only that EC2 instances run
as real Docker containers) — verified empirically instead of assuming: `terraform plan
-var="use_floci=true"` against Floci produces exactly the expected 5-resource plan (`aws_vpc`,
`aws_subnet`, `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`), so VPC-family
resources are in fact supported.
