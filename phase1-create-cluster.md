# Phase 1 — Create Kind Cluster

## Goal

Spin up a local kind cluster using `kind-config.yaml`.

## Builds on

Phase 0 (preflight checks passed).

## Steps

1. Check if cluster `devops-01` already exists — skip creation if it does
2. Run `kind create cluster --name devops-01 --config kind-config.yaml`
3. Set kubectl context to `kind-devops-01`

## Completion gate

See `tests/validate_cluster.sh`:

- [x] `kubectl get nodes` shows at least 1 node in `Ready` state (both control-plane and worker
      Ready — confirmed 2026-07-24)
- [x] `kubectl get pods -n kube-system` shows all pods `Running` or `Completed`

## Notes / decisions

Ran manually (Claude Code driving `kind`/`kubectl` directly, not `agent.py` — see project memory:
`agent.py` needs separate Anthropic API billing, which wasn't set up yet).

Found and fixed a real bug in `tests/validate_cluster.sh`: both count checks used
`grep -v ... | wc -l` under `set -o pipefail`. When the cluster is healthy and *zero* lines fail to
match, `grep -v`/`grep -Ev` itself exits 1 (no matches), and `pipefail` propagates that failure
through the whole pipeline before the count comparison runs — so the script failed exactly when
everything was fine. Fixed by wrapping each grep as `{ grep ... || true; }` so a "nothing matched"
result doesn't abort the script. Re-ran after the fix: passed cleanly.
