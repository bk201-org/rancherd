# Cluster test

Build rancherd with `make build`, then run the complete test against two fresh,
already-provisioned VMs:

```bash
bash .github/scripts/test-cluster.sh /path/to/ssh_config server-vm agent-vm
```

The VM names must match the SSH config aliases and become the Kubernetes node
names. Both VMs need passwordless sudo. The first VM bootstraps the cluster;
the second joins as an agent. VM provisioning and cleanup are handled separately.

The script prepares both VMs, installs the server, waits for its Rancher endpoint,
installs the agent, and waits for both nodes to become Ready. It stops at the
first failed stage. It works from any directory; relative SSH config and binary
paths are resolved from the caller's directory.

Versions default to Rancher `v2.15.1` and RKE2 `v1.36.4+rke2r1`. Override them or
the binary path through the environment:

```bash
RANCHER_VERSION=v2.15.1 \
KUBERNETES_VERSION=v1.36.4+rke2r1 \
RANCHERD_BINARY=/path/to/rancherd-amd64 \
bash .github/scripts/test-cluster.sh /path/to/ssh_config server-vm agent-vm
```

`WAIT_TIMEOUT_SECONDS` overrides each readiness wait's timeout (normally 1800
seconds for the server and 900 seconds for the complete cluster).

GitHub Actions invokes the same script with `VM_IDS` (a JSON array of two VM
names) and `CLUSTER_SSH_CONFIG` instead of positional arguments. The script
exports connection details through `GITHUB_ENV` even after a preparation failure,
so the separate diagnostics step can still inspect the VMs.

To collect diagnostics locally after a failure:

```bash
SSH_CONFIG=/path/to/ssh_config \
NODE1_ID=server-vm NODE2_ID=agent-vm \
bash .github/scripts/diagnostics.sh
```
