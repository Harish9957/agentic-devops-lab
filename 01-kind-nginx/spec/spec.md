# spec.md

## Goal

Use Claude as an agentic CLI (`agent.py`) to:
1. Create a local Kubernetes cluster using kind
2. Validate the cluster is healthy
3. Deploy a simple nginx application and verify it is reachable

This is the first exercise in a broader sandbox for exploring the agentic AI / AI-native platform
landscape from a DevOps background (Kubernetes, Terraform, GitLab, AWS, GPU/HAMi, KEDA, Karpenter —
see the notes in `CLAUDE.md` on which of those do and don't map onto a local Kind cluster).

## Non-Negotiable Rules

Bound by the repo-wide phase conventions in root [`CLAUDE.md`](../../CLAUDE.md#phase-conventions-non-negotiable-applies-to-every-use-case)
(phased progression, tests as the real gate, no partial states, idempotent operations). Nothing
use-case-specific to add here — this use case doesn't deviate from the shared conventions.

## Phases

Each phase has its own doc with the full goal, steps, and completion gate. Don't start phase N until
phase N-1's gate has passed.

- [`phases/phase0-preflight.md`](./phases/phase0-preflight.md) — confirm tooling and Docker are ready
- [`phases/phase1-create-cluster.md`](./phases/phase1-create-cluster.md) — create the kind cluster, validate health
- [`phases/phase2-deploy-nginx.md`](./phases/phase2-deploy-nginx.md) — deploy nginx, validate it's reachable

Later phases (KEDA autoscaling, GitOps for agent config, GPU/HAMi, GitLab CI) get scoped and added
here once phase 2 is solid — don't pre-write the whole roadmap up front.

Cluster teardown is not a phase (it's a reset, not forward progress) — see
[`teardown.md`](./teardown.md).

## Completion Promise

After all phases pass the agent will output:

```
✓ Phase 0 — Preflight         PASSED
✓ Phase 1 — Cluster healthy   PASSED
✓ Phase 2 — Nginx reachable   PASSED

Cluster: devops-01
Nginx URL: http://localhost:8080
```
