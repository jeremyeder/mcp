#!/bin/bash
# Check MCP ACP Configuration

echo "=== MCP ACP Configuration Check ==="
echo ""

# Check clusters.yaml
echo "1. Checking clusters.yaml configuration:"
CONFIG_FILE="$HOME/.config/acp/clusters.yaml"
if [ -f "$CONFIG_FILE" ]; then
    echo "   ✓ Config file exists: $CONFIG_FILE"
    echo ""
    echo "   Contents:"
    cat "$CONFIG_FILE"
    echo ""

    # Parse and show key values
    echo "   Parsed configuration:"
    if command -v python3 &> /dev/null; then
        python3 << 'PYEOF'
import yaml
from pathlib import Path

config_path = Path.home() / ".config" / "acp" / "clusters.yaml"
with open(config_path) as f:
    config = yaml.safe_load(f)

default_cluster = config.get("default_cluster")
print(f"   - default_cluster: {default_cluster}")

if default_cluster:
    cluster_config = config.get("clusters", {}).get(default_cluster, {})
    print(f"   - server: {cluster_config.get('server')}")
    print(f"   - default_project: {cluster_config.get('default_project')}")
    print(f"   - description: {cluster_config.get('description')}")
else:
    print("   ⚠ No default_cluster set!")
PYEOF
    fi
else
    echo "   ✗ Config file not found: $CONFIG_FILE"
fi
echo ""

# Check current oc context
echo "2. Current OpenShift context:"
if command -v oc &> /dev/null; then
    echo "   Current user: $(oc whoami 2>/dev/null || echo 'not logged in')"
    echo "   Current server: $(oc whoami --show-server 2>/dev/null || echo 'unknown')"
    echo "   Current project (oc): $(oc project -q 2>/dev/null || echo 'unknown')"
else
    echo "   ✗ oc command not found"
fi
echo ""

# Test MCP server config reading
echo "3. Test MCP server config reading:"
if command -v python3 &> /dev/null; then
    python3 << 'PYEOF'
import sys
try:
    # Import the client
    from mcp_acp.client import ACPClient

    # Create client
    client = ACPClient()

    print(f"   ✓ MCP client initialized")
    print(f"   Config loaded: {len(client.config.get('clusters', {}))} cluster(s)")

    default_cluster = client.config.get("default_cluster")
    print(f"   Default cluster: {default_cluster}")

    if default_cluster:
        cluster_config = client.config.get("clusters", {}).get(default_cluster, {})
        default_project = cluster_config.get("default_project")
        print(f"   Default project from config: {default_project}")

except ImportError as e:
    print(f"   ✗ Cannot import mcp_acp: {e}")
except Exception as e:
    print(f"   ✗ Error: {e}")
PYEOF
else
    echo "   ✗ python3 not found"
fi
echo ""

# Check permissions
echo "4. Check permissions in configured project:"
if command -v oc &> /dev/null && command -v python3 &> /dev/null; then
    python3 << 'PYEOF'
import yaml
import subprocess
from pathlib import Path

config_path = Path.home() / ".config" / "acp" / "clusters.yaml"
try:
    with open(config_path) as f:
        config = yaml.safe_load(f)

    default_cluster = config.get("default_cluster")
    if default_cluster:
        cluster_config = config.get("clusters", {}).get(default_cluster, {})
        default_project = cluster_config.get("default_project")

        if default_project:
            print(f"   Checking permissions in project: {default_project}")

            # Check if can get agenticsessions
            result = subprocess.run(
                ["oc", "auth", "can-i", "get", "agenticsessions.vteam.ambient-code", "-n", default_project],
                capture_output=True,
                text=True
            )
            can_get = result.stdout.strip() == "yes"
            print(f"   - Can GET agenticsessions: {'✓ yes' if can_get else '✗ no'}")

            # Check if can list
            result = subprocess.run(
                ["oc", "auth", "can-i", "list", "agenticsessions.vteam.ambient-code", "-n", default_project],
                capture_output=True,
                text=True
            )
            can_list = result.stdout.strip() == "yes"
            print(f"   - Can LIST agenticsessions: {'✓ yes' if can_list else '✗ no'}")

            if not can_get or not can_list:
                print(f"\n   ⚠ You need RBAC permissions for agenticsessions in {default_project}")
                print(f"   Contact your cluster admin or check: oc describe rolebinding -n {default_project}")
        else:
            print("   ⚠ No default_project configured")
    else:
        print("   ⚠ No default_cluster configured")
except Exception as e:
    print(f"   ✗ Error: {e}")
PYEOF
fi
echo ""

echo "=== Summary ==="
echo "If you see issues above, check:"
echo "1. clusters.yaml has correct default_cluster and default_project"
echo "2. You're logged into the correct OpenShift cluster"
echo "3. You have permissions in the configured default_project"
echo ""
echo "Example clusters.yaml:"
echo "---"
echo "clusters:"
echo "  my-cluster:"
echo "    server: https://api.your-cluster.com:6443"
echo "    default_project: jeder-workspace"
echo "    description: 'My Cluster'"
echo ""
echo "default_cluster: my-cluster"
echo "---"
