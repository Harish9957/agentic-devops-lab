# spec.md

## Goal

Use Terraform to create a minimal-but-correct AWS VPC by hand: a public subnet (internet-facing infra
only) and a private subnet (where compute actually goes), each wired to the internet appropriately —
public via Internet Gateway, private via NAT Gateway. This is the lab's first Terraform use case,
built without an installed Terraform "skill"/plugin on purpose — the point is learning the
fundamentals (provider config, resource dependencies, plan vs. apply, state) alongside building, not
getting a correct-looking result from baked-in conventions.

## Inputs

Configurable via `variables.tf`, all with defaults — `terraform plan`/`apply` need no `-var` flags
unless overriding one:

| Variable | Purpose | Default |
|---|---|---|
| `aws_region` | AWS region to create the VPC in | `us-east-1` |
| `name` | Name prefix applied to all resources | `agentic-devops-lab-02` |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` |
| `public_subnet_cidr` | CIDR block for the public subnet | `10.0.1.0/24` |
| `private_subnet_cidr` | CIDR block for the private subnet | `10.0.2.0/24` |
| `public_availability_zone` | AZ for the public subnet | `us-east-1a` |
| `private_availability_zone` | AZ for the private subnet — deliberately different, so it survives an AZ outage in the public subnet | `us-east-1b` |
| `use_floci` | Target a local [Floci](https://floci.io/) emulator (`http://localhost:4566`) instead of real AWS | `false` |

## Outputs

Exposed via `outputs.tf` once applied. A later use case that needs this VPC (an EKS cluster, EC2
instances, etc.) should consume these via `terraform_remote_state`, pointed at the shared
`terraform-state-backend/` bucket/key (see below) — rather than hardcoding IDs:

| Output | What it is |
|---|---|
| `vpc_id` | ID of the created VPC |
| `public_subnet_id` | ID of the public subnet — internet-facing infra only (NAT gateway, load balancers, bastions), never compute |
| `private_subnet_id` | ID of the private subnet — where compute resources (EC2, EKS nodes, etc.) should actually be created |

## Non-Negotiable Rules

1. **Phased progression**: same as `01-kind-nginx` — complete phases sequentially, confirm each
   gate before advancing.
2. **Plan before apply, always reviewed**: `terraform plan` output gets read and understood before
   any `terraform apply`.
3. **No `apply` or `destroy` without explicit go-ahead, every single time** — not just once at the
   start of this use case. This is a repo-wide rule for any real-cloud work (see root `CLAUDE.md`);
   it's called out here because this is the first use case where it applies.
4. **Remote state with locking**: state lives in the shared S3 bucket + DynamoDB lock table defined
   in [`../terraform-state-backend/`](../terraform-state-backend/), not locally. This started as
   local-only state (deliberately, to not conflate learning VPC basics with state management in the
   same pass) and was migrated once that was solid — see phase 2 notes and
   `terraform-state-backend/spec/phases/phase2-apply.md` for how the migration was done and verified.

## Phases

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm terraform + AWS credentials
- [`phases/phase1-plan.md`](./phases/phase1-plan.md) — write the VPC code, get a reviewed plan (no apply)
- [`phases/phase2-apply.md`](./phases/phase2-apply.md) — apply the reviewed plan (blocked pending
  your explicit go-ahead)

Teardown is documented separately, not as a phase: [`teardown.md`](./teardown.md).

## Completion Promise

```
✓ Phase 0 — Preflight              PASSED (Floci path; real-AWS path still blocked on credentials)
✓ Phase 1 — Plan reviewed          PASSED (base VPC + private-subnet/NAT extension, both against Floci)
✓ Phase 2 — Apply                  PASSED in full (base VPC + private subnet/NAT, both authorized
                                    separately, both against Floci, 2026-07-25)

vpc_id:            vpc-e705db27      (Floci-emulated, not real AWS)
public_subnet_id:  subnet-d7a7dd89   (Floci-emulated, not real AWS)
private_subnet_id: subnet-9f7fb509   (Floci-emulated, not real AWS)
```
