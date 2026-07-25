# Phase 0 — Preflight

## Goal

Confirm Terraform is installed and either real AWS credentials or a running Floci emulator are
available, before writing or planning anything. Same pattern as `02-terraform-vpc`'s phase 0.

## Builds on

Nothing — first phase of this shared-infra directory.

## Checks

- `terraform version` exits 0
- Either: `aws sts get-caller-identity` exits 0 against real AWS, **or**: `floci start` is running
  and `var.use_floci = true` is set.

## Completion gate

- [x] `terraform version` prints a version (v1.15.1)
- [ ] `aws sts get-caller-identity` succeeds (real AWS path) — still blocked, same as `02`
- [x] Floci is running and reachable at `http://localhost:4566` (Floci path — container `floci`,
      healthy, confirmed 2026-07-25 via `docker ps` and `/_localstack/health` returning 200)

## Notes / decisions

2026-07-25: same Floci container already running from `02-terraform-vpc` work reused here — no
separate install/start needed. Real AWS path stays blocked on credentials, same open item as `02`.
