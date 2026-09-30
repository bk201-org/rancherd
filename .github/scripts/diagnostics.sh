#!/usr/bin/env bash
# Best-effort dump of service logs and cluster state after a failure.
# Safe to run even when the earlier steps did not set up the nodes.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ -n "${NODE1_ID:-}" ] || exit 0

# run_group <title> <node> <remote command>
# Prints the output as its own collapsible group so logs never interleave.
run_group() {
  echo "::group::$1"
  ssh_vm "$2" "$3" </dev/null 2>&1 || true
  echo "::endgroup::"
}

# node_logs <node> <role> <rke2 unit>
node_logs() {
  local node=$1 role=$2 unit=$3
  run_group "[$role] $node: rancherd status" "$node" "sudo systemctl status rancherd --no-pager"
  run_group "[$role] $node: rancherd journal (last 200)" "$node" "sudo journalctl -u rancherd -n 200 --no-pager"
  run_group "[$role] $node: $unit journal (last 100)" "$node" "sudo journalctl -u $unit -n 100 --no-pager"
}

node_logs "$NODE1_ID" server rke2-server
[ -z "${NODE2_ID:-}" ] || node_logs "$NODE2_ID" agent rke2-agent

echo "::group::[cluster] nodes"
kctl get nodes -o wide 2>&1 || true
echo "::endgroup::"

echo "::group::[cluster] pods"
kctl get pods -A 2>&1 || true
echo "::endgroup::"
