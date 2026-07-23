# Agentic DevOps 01 — Spec

## Goal

Use Claude as an agentic CLI to:
1. Create a local Kubernetes cluster using kind
2. Validate the cluster is healthy
3. Deploy a simple nginx application and verify it is reachable

---

## Non-Negotiable Rules

1. **Phased progression**: Complete phases sequentially; halt after each phase and confirm tests pass before advancing
2. **Test-first approach**: Run validation checks after every phase — halt on failure, surface the error clearly
3. **No partial states**: If a phase fails mid-way, report the exact step and output before stopping
4. **Idempotent operations**: Every command must be safe to re-run without side effects

---

## Phases

### Phase 0 — Preflight

**Goal**: Confirm all required tools are installed and Docker is running.

**Checks:**
- `kind version` exits 0
- `kubectl version --client` exits 0
- `docker info` exits 0

**Completion gate**: All three checks pass → proceed to Phase 1.

---

### Phase 1 — Create Kind Cluster

**Goal**: Spin up a local kind cluster using `kind-config.yaml`.

**Steps:**
1. Check if cluster `devops-01` already exists — skip creation if it does
2. Run `kind create cluster --name devops-01 --config kind-config.yaml`
3. Set kubectl context to `kind-devops-01`

**Completion gate** (see `tests/validate_cluster.sh`):
- `kubectl get nodes` shows at least 1 node in `Ready` state
- `kubectl get pods -n kube-system` shows all pods `Running` or `Completed`

---

### Phase 2 — Deploy Nginx

**Goal**: Deploy nginx to the cluster and confirm it is reachable.

**Steps:**
1. Apply `manifests/nginx-deployment.yaml`
2. Wait for rollout: `kubectl rollout status deployment/nginx -n default --timeout=120s`
3. Port-forward and curl to verify HTTP 200

**Completion gate** (see `tests/validate_nginx.sh`):
- Pod with label `app=nginx` is in `Running` state
- `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080` returns `200`

---

## Completion Promise

After all phases pass the agent will output:

```
✓ Phase 0 — Preflight         PASSED
✓ Phase 1 — Cluster healthy   PASSED
✓ Phase 2 — Nginx reachable   PASSED

Cluster: devops-01
Nginx URL: http://localhost:8080
```
