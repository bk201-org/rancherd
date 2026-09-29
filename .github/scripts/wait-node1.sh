#!/usr/bin/env bash
# Wait until node 1 is Ready and its Rancher endpoint is reachable from node 2,
# which is what a joining node needs to download the cluster CA certificates.
#
# Environment:
#   WAIT_TIMEOUT_SECONDS  default 1800
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

deadline=$((SECONDS + ${WAIT_TIMEOUT_SECONDS:-1800}))
node_ready=false
while [ "$SECONDS" -lt "$deadline" ]; do
  fail_if_rancherd_failed "$NODE1_ID"
  if [ "$node_ready" != true ]; then
    out=$(kctl get nodes --no-headers 2>/dev/null || true)
    if awk '$2 ~ /^Ready/ {found = 1} END {exit !found}' <<< "$out"; then
      echo "node 1 is Ready"
      node_ready=true
    fi
  fi
  if [ "$node_ready" = true ] &&
     ssh_vm "$NODE2_ID" "curl -ksf -o /dev/null https://$NODE1_IP:8443/cacerts" </dev/null; then
    echo "Rancher endpoint https://$NODE1_IP:8443 is reachable from node 2"
    exit 0
  fi
  sleep 10
done
echo "::error::node 1 did not become ready in time"
exit 1
