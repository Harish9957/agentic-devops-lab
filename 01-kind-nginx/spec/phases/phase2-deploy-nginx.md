# Phase 2 — Deploy Nginx

## Goal

Deploy nginx to the cluster and confirm it is reachable.

## Builds on

Phase 1 (cluster `devops-01` healthy).

## Steps

1. Apply `manifests/nginx-deployment.yaml`
2. Wait for rollout: `kubectl rollout status deployment/nginx -n default --timeout=120s`
3. Port-forward and curl to verify HTTP 200

## Completion gate

See `tests/validate_nginx.sh`:

- [x] Pod with label `app=nginx` is in `Running` state
- [x] `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080` returns `200`

## Notes / decisions

Ran manually (same as phase 1 — `agent.py` still blocked on Anthropic API billing). Applied
`manifests/nginx-deployment.yaml`, rollout succeeded, `tests/validate_nginx.sh` passed on the first
try — no changes needed to the manifest or the script.
