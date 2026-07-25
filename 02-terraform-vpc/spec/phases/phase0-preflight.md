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

## Design rule (non-negotiable, applies to every phase in this use case)

**Compute resources (EC2, EKS nodes, RDS, etc.) always go in a private subnet. The public subnet is
reserved for internet-facing infra only — NAT gateway, load balancers, bastion hosts.** Never place
compute directly in the public subnet just because it's simpler to reach. This is why the VPC has
both a public subnet (`aws_subnet.public`, routed to an Internet Gateway) and a private subnet
(`aws_subnet.private`, routed to a NAT Gateway that sits in the public subnet) — any future use case
that needs to launch compute against this VPC must consume `private_subnet_id`, not
`public_subnet_id`, from this use case's outputs.

## Completion gate

- [x] `terraform version` prints a version (v1.15.1 — a newer 1.15.8 is available but not required)
- [ ] `aws sts get-caller-identity` succeeds and shows the expected Account ID (still open — real AWS
      credentials not configured on this machine)
- [x] Floci path confirmed working: `floci start` brings up the emulator at `http://localhost:4566`;
      `terraform plan -var="use_floci=true"` succeeds (see phase 1 notes)
- [x] Design rule satisfied: VPC has a dedicated private subnet, separate from the public subnet
      (see phase 1 notes for the resources added)

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

Checked 2026-07-25 (later same day): the original design only had a public subnet — every resource,
including future compute, would have landed there directly. That's wrong for anything beyond a
throwaway demo: added a private subnet + NAT Gateway (`aws_eip.nat`, `aws_nat_gateway.main`,
`aws_route_table.private`, `aws_route_table_association.private`) and turned "compute goes in
private, not public" into the standing design rule above rather than a one-off fix. See phase 1
notes for the plan verification of these additional resources.
