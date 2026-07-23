#!/usr/bin/env bash
set -euo pipefail

CONTEXT="kind-devops-01"

echo "==> Checking nodes are Ready..."
NOT_READY=$(kubectl --context "$CONTEXT" get nodes --no-headers | grep -v " Ready" | wc -l | tr -d ' ')
if [ "$NOT_READY" -gt 0 ]; then
  echo "FAIL: $NOT_READY node(s) not Ready"
  kubectl --context "$CONTEXT" get nodes
  exit 1
fi
echo "    Nodes: OK"

echo "==> Checking kube-system pods..."
NOT_RUNNING=$(kubectl --context "$CONTEXT" get pods -n kube-system --no-headers \
  | grep -Ev "Running|Completed" | wc -l | tr -d ' ')
if [ "$NOT_RUNNING" -gt 0 ]; then
  echo "FAIL: $NOT_RUNNING kube-system pod(s) not healthy"
  kubectl --context "$CONTEXT" get pods -n kube-system
  exit 1
fi
echo "    kube-system pods: OK"

echo "PASSED: cluster is healthy"
