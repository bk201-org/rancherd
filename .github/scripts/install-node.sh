#!/usr/bin/env bash
# Write the rancherd config for a node and start rancherd on it.
#
# Usage: install-node.sh cluster-init|agent
#   cluster-init  bootstrap node 1 with RKE2
#   agent         join node 2 to node 1 as a worker
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
  cluster-init)
    install_rancherd "$NODE1_ID" <<EOF
role: cluster-init
token: $RANCHERD_TEST_TOKEN
kubernetesVersion: stable:rke2
EOF
    ;;
  agent)
    install_rancherd "$NODE2_ID" <<EOF
role: agent
server: https://$NODE1_IP:8443
token: $RANCHERD_TEST_TOKEN
EOF
    ;;
  *)
    echo "usage: $0 cluster-init|agent" >&2
    exit 2
    ;;
esac
