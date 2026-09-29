#!/usr/bin/env bash
# Wait for SSH on both VMs, copy rancherd and its Harvester bootstrap fixtures,
# and export the variables used by the other scripts through GITHUB_ENV.
#
# Environment:
#   VM_IDS              JSON array of VM IDs from the create-ci-cluster action
#   CLUSTER_SSH_CONFIG  SSH config path from the create-ci-cluster action
#   RANCHER_VERSION     Rancher version used in the chart values and node config
#   RANCHERD_BINARY     Binary to install (default: bin/rancherd-amd64)
set -euo pipefail

: "${VM_IDS:?}" "${CLUSTER_SSH_CONFIG:?}" "${GITHUB_ENV:?}" "${RANCHER_VERSION:?}"
binary=${RANCHERD_BINARY:-bin/rancherd-amd64}
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fixtures_dir="$script_dir/../fixtures/rancherd"

# Only substitute the version placeholder, leaving all other chart values intact.
if [[ ! "$RANCHER_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+[-a-zA-Z0-9.+]*$ ]]; then
  echo "::error::RANCHER_VERSION must be a concrete version" >&2
  exit 1
fi
rendered_dir=$(mktemp -d)
trap 'rm -rf "$rendered_dir"' EXIT
defaults=$(< "$fixtures_dir/50-defaults.yaml")
printf '%s\n' "${defaults//\$\{RANCHER_VERSION\}/$RANCHER_VERSION}" > "$rendered_dir/50-defaults.yaml"

mapfile -t ids < <(jq -r '.[]' <<< "$VM_IDS")
if [ "${#ids[@]}" -ne 2 ]; then
  echo "expected 2 VMs, got ${#ids[@]}" >&2
  exit 1
fi

token=$(openssl rand -hex 16)
echo "::add-mask::$token"

export SSH_CONFIG=$CLUSTER_SSH_CONFIG
source "$script_dir/lib.sh"

node1_ip=$(ssh -T -F "$SSH_CONFIG" -G "${ids[0]}" | awk '$1 == "hostname" {print $2}')
if [ -z "$node1_ip" ]; then
  echo "::error::cannot determine the IP of ${ids[0]}"
  exit 1
fi

{
  echo "SSH_CONFIG=$SSH_CONFIG"
  echo "NODE1_ID=${ids[0]}"
  echo "NODE2_ID=${ids[1]}"
  echo "NODE1_IP=$node1_ip"
  echo "RANCHER_SERVER_URL=https://$node1_ip:443"
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
  scp -F "$SSH_CONFIG" -o BatchMode=yes "$binary" install.sh "$rendered_dir/50-defaults.yaml" "$fixtures_dir/91-harvester-bootstrap-repo.yaml" "$id:/tmp/"
  ssh_vm "$id" "sudo install -m 0755 /tmp/$(basename "$binary") /usr/local/bin/rancherd && /usr/local/bin/rancherd info" </dev/null
  # Harvester normally supplies these files in the OS image. The repository
  # manifest is also read directly from this exact path during plan generation.
  ssh_vm "$id" 'sudo mkdir -p /usr/share/rancher/rancherd/config.yaml.d && sudo install -m 0644 /tmp/50-defaults.yaml /tmp/91-harvester-bootstrap-repo.yaml /usr/share/rancher/rancherd/config.yaml.d/' </dev/null
  echo "::endgroup::"
done
