# spec.md

## Goal

Create a shared, secure S3 + DynamoDB Terraform state backend, reusable by every Terraform use case
in this repo (starting with `02-terraform-vpc`) rather than each use case bootstrapping its own
bucket/table. One bucket holds every use case's state, distinguished by backend `key`; one DynamoDB
table handles locking for all of them.

This directory is unnumbered, like `01-kind-nginx/spec/teardown.md` — it isn't a use case with its
own forward-building narrative, it's shared infrastructure other use cases depend on. See root
`CLAUDE.md`'s "Repo structure" section.

## Inputs

| Variable | Purpose | Default |
|---|---|---|
| `aws_region` | AWS region for the backend | `us-east-1` |
| `bucket_name` | S3 bucket name for state | `agentic-devops-lab-tfstate` |
| `dynamodb_table_name` | DynamoDB table name for locking | `agentic-devops-lab-tflocks` |
| `use_floci` | Target a local [Floci](https://floci.io/) emulator instead of real AWS | `false` |

Real AWS note: S3 bucket names must be globally unique. `bucket_name`'s default will very likely
collide with someone else's bucket on real AWS — override it with something unique before applying
against real AWS. Floci has no such constraint.

## Outputs

| Output | What it is |
|---|---|
| `bucket_name` | S3 bucket holding state — dependent use cases reference this in their `backend.hcl` |
| `dynamodb_table_name` | DynamoDB table for locking — same, via `backend.hcl` |

## Security properties (why this bucket is "secure")

- **Versioning enabled** — accidental state corruption/overwrite is recoverable from a prior version.
- **Encryption at rest** (SSE-S3/AES256, bucket-key enabled) — state files can contain sensitive
  values (e.g. resource ARNs, sometimes secrets if a provider ever returns one in a resource attribute).
- **Public access fully blocked** (all four `aws_s3_bucket_public_access_block` settings) — state
  should never be reachable outside this AWS account.
- **TLS-only bucket policy** — denies any request over plain HTTP (`aws:SecureTransport = false`).
- **Locking via DynamoDB** (`LockID` hash key, on-demand billing) — prevents two concurrent
  `terraform apply` runs from corrupting the same state file.

## Non-Negotiable Rules

1. **No `apply` or `destroy` without explicit go-ahead, every single time** — same repo-wide rule as
   every other real-cloud use case (see root `CLAUDE.md`).
2. **This backend is a dependency, not a use case** — once `02-terraform-vpc` (or any later use case)
   migrates its state here, don't destroy this bucket/table without first confirming no dependent
   use case still points at it.
3. **Local state for bootstrapping this backend itself** — chicken-and-egg: this can't use the remote
   backend it creates, so it uses local state, same as `02-terraform-vpc` did before this existed.

## Phases

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm terraform + AWS
  credentials/Floci
- [`phases/phase1-plan.md`](./phases/phase1-plan.md) — write the backend code, get a reviewed plan
- [`phases/phase2-apply.md`](./phases/phase2-apply.md) — apply the reviewed plan (blocked pending
  explicit go-ahead), then migrate `02-terraform-vpc`'s state into it

## Completion Promise

```
✓ Phase 0 — Preflight              PASSED
✓ Phase 1 — Plan reviewed          PASSED
✓ Phase 2 — Apply + migration      PASSED (against Floci, authorized 2026-07-25)

bucket_name:           agentic-devops-lab-tfstate   (Floci-emulated, not real AWS)
dynamodb_table_name:   agentic-devops-lab-tflocks   (Floci-emulated, not real AWS)
```

`02-terraform-vpc`'s state now lives here (key `02-terraform-vpc/terraform.tfstate`), migrated with
all 10 resources intact and locking verified working.
