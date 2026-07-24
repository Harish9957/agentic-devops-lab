# Phase 0 — Preflight

## Goal

Confirm Terraform is installed and AWS credentials are configured and actually valid, before
writing or planning anything.

## Builds on

Nothing — first phase of this use case.

## Checks

- `terraform version` exits 0
- `aws sts get-caller-identity` exits 0 (confirms credentials are present *and* actually work
  against a real AWS account — a present-but-invalid/expired credential is the common failure mode
  here, not just "is the AWS CLI installed")

## Completion gate

- [x] `terraform version` prints a version (v1.15.1 — a newer 1.15.8 is available but not required)
- [ ] `aws sts get-caller-identity` succeeds and shows the expected Account ID

## Notes / decisions

Checked 2026-07-24: `aws sts get-caller-identity` fails with `NoCredentials` — no AWS credentials
configured on this machine yet. Confirmed this is the actual blocker (not just an untested
assumption) by also running `terraform plan`, which failed the same way: `No valid credential
sources found` / `no EC2 IMDS role found`. Phase 0 stays open until credentials are configured;
phase 1's plan can't be completed until then either.
