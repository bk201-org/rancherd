#!/usr/bin/env bash
# Write the rancherd config for a node and start rancherd on it.
#
# Usage: install-node.sh cluster-init|agent
# Versions and node names come from the test-cluster workflow environment.
# The join endpoint and random token are exported by prepare-nodes.sh.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
  cluster-init)
    node_id=${NODE1_ID:?}
    node_name=${NODE1_NAME:?}
    ;;
  agent)
    node_id=${NODE2_ID:?}
    node_name=${NODE2_NAME:?}
    : "${RANCHER_SERVER_URL:?}"
    ;;
  *)
    echo "usage: $0 cluster-init|agent" >&2
    exit 2
    ;;
esac

: "${RANCHERD_TEST_TOKEN:?}" "${KUBERNETES_VERSION:?}" "${RANCHER_VERSION:?}"
{
  if [ "$1" = agent ]; then
    printf 'server: "%s"\n' "$RANCHER_SERVER_URL"
  fi
  cat <<EOF
role: $1
nodeName: "$node_name"
token: "$RANCHERD_TEST_TOKEN"
kubernetesVersion: "$KUBERNETES_VERSION"
rancherVersion: "$RANCHER_VERSION"
rancherInstallerImage: "rancher/system-agent-installer-rancher:$RANCHER_VERSION"
labels:
- harvesterhci.io/managed=true
extraConfig:
  # Rancher binds port 443 directly in this CI cluster.
  ingress-controller: none
  disable:
  - rke2-snapshot-controller
  - rke2-snapshot-controller-crd
  - rke2-snapshot-validation-webhook
EOF
} | install_rancherd "$node_id"
