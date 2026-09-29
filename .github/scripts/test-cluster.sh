#!/usr/bin/env bash
# Run the cluster test against two already-provisioned VMs.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: test-cluster.sh SSH_CONFIG SERVER_VM AGENT_VM
       VM_IDS='["server-vm","agent-vm"]' CLUSTER_SSH_CONFIG=/path/to/ssh_config test-cluster.sh

Build rancherd with make build first. VM names must be aliases in the SSH
config, with passwordless sudo on both VMs. The first VM becomes the server.

Optional environment:
  RANCHERD_BINARY        Default: <repo>/bin/rancherd-amd64
  RANCHER_VERSION       Default: v2.15.1
  KUBERNETES_VERSION    Default: v1.36.4+rke2r1
  WAIT_TIMEOUT_SECONDS  Override the readiness timeout for each wait stage

Diagnostics are run separately with diagnostics.sh.
EOF
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  usage
  exit 0
fi
if [ "$#" -eq 3 ]; then
  export CLUSTER_SSH_CONFIG=$1
  export VM_IDS
  VM_IDS=$(jq -cn --arg server "$2" --arg agent "$3" '[$server, $agent]')
elif [ "$#" -ne 0 ]; then
  usage >&2
  exit 2
fi
: "${VM_IDS:?provide two VM names}" "${CLUSTER_SSH_CONFIG:?provide an SSH config}"

# Resolve caller-relative paths before changing to the checkout directory.
export CLUSTER_SSH_CONFIG
CLUSTER_SSH_CONFIG=$(realpath "$CLUSTER_SSH_CONFIG")
if [ -n "${RANCHERD_BINARY:-}" ]; then
  export RANCHERD_BINARY
  RANCHERD_BINARY=$(realpath "$RANCHERD_BINARY")
fi
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$script_dir/../.."
export RANCHER_VERSION=${RANCHER_VERSION:-v2.15.1}
export KUBERNETES_VERSION=${KUBERNETES_VERSION:-v1.36.4+rke2r1}

state_dir=$(mktemp -d)
export CLUSTER_ENV_FILE="$state_dir/cluster.env"
cleanup() {
  local status=$?
  # Preparation writes connection details before touching the VMs. Preserve
  # them for the separate Actions diagnostics step even if preparation fails.
  if [ -n "${GITHUB_ENV:-}" ] && [ -f "$CLUSTER_ENV_FILE" ]; then
    cat "$CLUSTER_ENV_FILE" >> "$GITHUB_ENV" || status=1
  fi
  rm -rf "$state_dir"
  exit "$status"
}
trap cleanup EXIT

run_stage() {
  echo "=== $1 ==="
  shift
  local script=$1
  shift
  bash "$script_dir/$script" "$@"
}

run_stage 'Prepare nodes' prepare-nodes.sh
# Read assignments as data so paths with spaces are safe and never evaluated.
while IFS='=' read -r key value; do
  export "$key=$value"
done < "$CLUSTER_ENV_FILE"
run_stage 'Bootstrap server' install-node.sh cluster-init
run_stage 'Wait for server' wait-node1.sh
run_stage 'Join agent' install-node.sh agent
run_stage 'Wait for both nodes' wait-cluster.sh
