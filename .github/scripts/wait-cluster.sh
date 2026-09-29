#!/usr/bin/env bash
# Wait until both nodes are Ready: one control-plane node and one agent.
#
# Environment:
#   WAIT_TIMEOUT_SECONDS  default 900
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

deadline=$((SECONDS + ${WAIT_TIMEOUT_SECONDS:-900}))
while [ "$SECONDS" -lt "$deadline" ]; do
  fail_if_rancherd_failed "$NODE2_ID"
  out=$(kctl get nodes --no-headers 2>/dev/null || true)
  ready=$(awk '$2 ~ /^Ready/ {n++} END {print n + 0}' <<< "$out")
  control_plane=$(awk '$2 ~ /^Ready/ && $3 ~ /control-plane/ {n++} END {print n + 0}' <<< "$out")
  echo "ready nodes: $ready, ready control-plane nodes: $control_plane"
  if [ "$ready" -eq 2 ] && [ "$control_plane" -eq 1 ]; then
    kctl get nodes -o wide
    exit 0
  fi
  sleep 10
done
echo "::error::expected 2 Ready nodes (1 control-plane, 1 agent)"
kctl get nodes -o wide || true
exit 1
