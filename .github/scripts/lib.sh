# Shared helpers for the cluster test scripts. Source this file; do not run it.
#
# Expected environment (loaded by test-cluster.sh, or GITHUB_ENV in Actions):
#   SSH_CONFIG, NODE1_ID, NODE2_ID, NODE1_IP, RANCHER_SERVER_URL,
#   RANCHERD_TEST_TOKEN

ssh_vm() {
  ssh -F "$SSH_CONFIG" -o BatchMode=yes -o ConnectTimeout=10 "$@"
}

# Run rke2 kubectl on the first node.
kctl() {
  ssh_vm "$NODE1_ID" "sudo env KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl $*" </dev/null
}

# Write the rancherd config read from stdin to node $1, then install and start
# the rancherd service using the binary already copied to the node.
install_rancherd() {
  ssh_vm "$1" 'sudo mkdir -p /etc/rancher/rancherd && sudo sh -c "umask 077 && cat > /etc/rancher/rancherd/config.yaml"'
  ssh_vm "$1" 'sudo env INSTALL_RANCHERD_SKIP_DOWNLOAD=true sh /tmp/install.sh' </dev/null
}

# Fail early when the rancherd service on node $1 has failed.
fail_if_rancherd_failed() {
  if ssh_vm "$1" 'systemctl is-failed --quiet rancherd' </dev/null; then
    echo "::error::rancherd failed on $1"
    return 1
  fi
}
