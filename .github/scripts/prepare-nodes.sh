#!/usr/bin/env bash
# Wait for SSH on both VMs, copy the rancherd binary and install.sh to them,
# and export the variables used by the other scripts through GITHUB_ENV.
#
# Environment:
#   VM_IDS              JSON array of VM IDs from the create-ci-cluster action
#   CLUSTER_SSH_CONFIG  SSH config path from the create-ci-cluster action
#   RANCHERD_BINARY     Binary to install (default: bin/rancherd-amd64)
set -euo pipefail

: "${VM_IDS:?}" "${CLUSTER_SSH_CONFIG:?}" "${GITHUB_ENV:?}"
binary=${RANCHERD_BINARY:-bin/rancherd-amd64}

mapfile -t ids < <(jq -r '.[]' <<< "$VM_IDS")
if [ "${#ids[@]}" -ne 2 ]; then
  echo "expected 2 VMs, got ${#ids[@]}" >&2
  exit 1
fi

token=$(openssl rand -hex 16)
echo "::add-mask::$token"

export SSH_CONFIG=$CLUSTER_SSH_CONFIG
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

node1_ip=$(ssh -F "$SSH_CONFIG" -G "${ids[0]}" | awk '$1 == "hostname" {print $2}')
if [ -z "$node1_ip" ]; then
  echo "::error::cannot determine the IP of ${ids[0]}"
  exit 1
fi

{
  echo "SSH_CONFIG=$SSH_CONFIG"
  echo "NODE1_ID=${ids[0]}"
  echo "NODE2_ID=${ids[1]}"
  echo "NODE1_IP=$node1_ip"
  echo "RANCHERD_TEST_TOKEN=$token"
} >> "$GITHUB_ENV"

chmod +x "$binary"
for id in "${ids[@]}"; do
  echo "::group::prepare $id"
  connected=false
  for attempt in $(seq 1 30); do
    if ssh_vm "$id" true; then
      connected=true
      break
    fi
    echo "SSH to $id not ready (attempt $attempt/30)"
    sleep 10
  done
  if [ "$connected" != true ]; then
    echo "::error::SSH to $id did not become ready"
    exit 1
  fi
  ssh_vm "$id" 'cloud-init status --wait' || true
  scp -F "$SSH_CONFIG" -o BatchMode=yes "$binary" install.sh "$id:/tmp/"
  ssh_vm "$id" "sudo install -m 0755 /tmp/$(basename "$binary") /usr/local/bin/rancherd && rancherd --version || true"
  echo "::endgroup::"
done
