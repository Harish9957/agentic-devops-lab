#!/usr/bin/env bash
set -euo pipefail

CONTEXT="kind-devops-01"
LOCAL_PORT=8080

echo "==> Checking nginx pod is Running..."
STATUS=$(kubectl --context "$CONTEXT" get pods -l app=nginx -n default \
  --no-headers -o custom-columns=":status.phase" 2>/dev/null | head -1)
if [ "$STATUS" != "Running" ]; then
  echo "FAIL: nginx pod status is '$STATUS'"
  kubectl --context "$CONTEXT" get pods -l app=nginx -n default
  exit 1
fi
echo "    Pod status: OK"

echo "==> Port-forwarding svc/nginx to localhost:$LOCAL_PORT..."
kubectl --context "$CONTEXT" port-forward svc/nginx "$LOCAL_PORT":80 -n default &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null" EXIT

sleep 2

echo "==> Curling http://localhost:$LOCAL_PORT..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$LOCAL_PORT")
if [ "$HTTP_CODE" != "200" ]; then
  echo "FAIL: expected HTTP 200, got $HTTP_CODE"
  exit 1
fi
echo "    HTTP $HTTP_CODE: OK"

echo "PASSED: nginx is reachable at http://localhost:$LOCAL_PORT"
