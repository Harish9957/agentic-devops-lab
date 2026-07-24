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

1. **Phased progression**: Complete phases sequentially; halt after each phase and confirm tests pass before advancing
2. **Test-first approach**: Run validation checks after every phase — halt on failure, surface the error clearly
3. **No partial states**: If a phase fails mid-way, report the exact step and output before stopping
4. **Idempotent operations**: Every command must be safe to re-run without side effects

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
