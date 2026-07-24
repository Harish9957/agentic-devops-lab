# spec.md

## Goal

Use Terraform to create a minimal AWS VPC by hand: one VPC, one public subnet, an Internet Gateway,
and a route table wiring the subnet to the internet (5 resources total). This is the lab's first
Terraform use case, built without an installed Terraform "skill"/plugin on purpose — the point is
learning the fundamentals (provider config, resource dependencies, plan vs. apply, state) alongside
building, not getting a correct-looking result from baked-in conventions.

## Non-Negotiable Rules

1. **Phased progression**: same as `01-kind-nginx` — complete phases sequentially, confirm each
   gate before advancing.
2. **Plan before apply, always reviewed**: `terraform plan` output gets read and understood before
   any `terraform apply`.
3. **No `apply` or `destroy` without explicit go-ahead, every single time** — not just once at the
   start of this use case. This is a repo-wide rule for any real-cloud work (see root `CLAUDE.md`);
   it's called out here because this is the first use case where it applies.
4. **Local state only** for this exercise. Remote state backends (S3 + DynamoDB locking, etc.) are
   a deliberately separate, later use case — don't conflate learning VPC basics with learning state
   management in the same pass.

## Phases

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm terraform + AWS credentials
- [`phases/phase1-plan.md`](./phases/phase1-plan.md) — write the VPC code, get a reviewed plan (no apply)
- [`phases/phase2-apply.md`](./phases/phase2-apply.md) — apply the reviewed plan (blocked pending
  your explicit go-ahead)

Teardown is documented separately, not as a phase: [`teardown.md`](./teardown.md).

## Completion Promise

```
✓ Phase 0 — Preflight              PASSED
✓ Phase 1 — Plan reviewed          PASSED
⧗ Phase 2 — Apply                  BLOCKED (awaiting your explicit go-ahead)
```
