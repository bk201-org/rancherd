#!/usr/bin/env bash
# Best-effort dump of service logs and cluster state after a failure.
# Safe to run even when the earlier steps did not set up the nodes.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ -n "${NODE1_ID:-}" ] || exit 0

node_logs() {
  echo "::group::$1 ($2)"
  ssh_vm "$1" "sudo systemctl status rancherd --no-pager; sudo journalctl -u rancherd -n 200 --no-pager; sudo journalctl -u $2 -n 100 --no-pager" </dev/null || true
  echo "::endgroup::"
}

node_logs "$NODE1_ID" rke2-server
[ -z "${NODE2_ID:-}" ] || node_logs "$NODE2_ID" rke2-agent

echo "::group::cluster state"
kctl get nodes -o wide || true
kctl get pods -A || true
echo "::endgroup::"
