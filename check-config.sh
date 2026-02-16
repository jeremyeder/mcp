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

    # Check file permissions
    PERMS=$(stat -f "%Lp" "$CONFIG_FILE" 2>/dev/null || stat -c "%a" "$CONFIG_FILE" 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo "   ✓ File permissions: $PERMS (secure)"
    else
        echo "   ⚠ File permissions: $PERMS (should be 600 — file contains tokens)"
        echo "     Fix: chmod 600 $CONFIG_FILE"
    fi
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

clusters = config.get("clusters", {})
print(f"   - clusters configured: {len(clusters)}")

if default_cluster:
    cluster_config = clusters.get(default_cluster, {})
    server = cluster_config.get("server", "not set")
    project = cluster_config.get("default_project", "not set")
    has_token = "yes" if cluster_config.get("token") else "no"
    description = cluster_config.get("description", "")

    print(f"   - server: {server}")
    print(f"   - default_project: {project}")
    print(f"   - token configured: {has_token}")
    if description:
        print(f"   - description: {description}")

    # Check for port 6443 (direct K8s API)
    if ":6443" in server:
        print()
        print("   ⚠ WARNING: Server URL uses port 6443 (direct K8s API)")
        print("     Use the public-api gateway URL instead:")
        print("     e.g., https://public-api-ambient.apps.cluster.example.com")
else:
    print("   ⚠ No default_cluster set!")
PYEOF
    fi
else
    echo "   ✗ Config file not found: $CONFIG_FILE"
    echo "     Create it with: mkdir -p ~/.config/acp && cp clusters.yaml.example ~/.config/acp/clusters.yaml"
fi
echo ""

# Check ACP_TOKEN environment variable
echo "2. Checking ACP_TOKEN environment variable:"
if [ -n "$ACP_TOKEN" ]; then
    echo "   ✓ ACP_TOKEN is set (${#ACP_TOKEN} characters)"
else
    echo "   - ACP_TOKEN is not set (will use token from clusters.yaml)"
fi
echo ""

# Test MCP server config loading
echo "3. Test MCP server config loading:"
if command -v python3 &> /dev/null; then
    python3 << 'PYEOF'
import sys
try:
    from mcp_acp.settings import load_settings, load_clusters_config

    settings = load_settings()
    config = load_clusters_config(settings)

    print(f"   ✓ Config loaded successfully")
    print(f"   Clusters: {list(config.clusters.keys())}")
    print(f"   Default cluster: {config.default_cluster}")

    if config.default_cluster:
        cluster = config.clusters.get(config.default_cluster)
        if cluster:
            has_token = bool(cluster.token)
            print(f"   Token configured: {'yes' if has_token else 'no'}")
            print(f"   Server: {cluster.server}")
            print(f"   Default project: {cluster.default_project}")

except ImportError as e:
    print(f"   ✗ Cannot import mcp_acp: {e}")
    print(f"     Install with: uv pip install -e '.[dev]'")
except FileNotFoundError as e:
    print(f"   ✗ Config file not found: {e}")
except Exception as e:
    print(f"   ✗ Error: {e}")
PYEOF
else
    echo "   ✗ python3 not found"
fi
echo ""

echo "=== Summary ==="
echo "If you see issues above, check:"
echo "1. clusters.yaml has correct server (gateway URL), token, and default_project"
echo "2. File permissions are 600 (chmod 600 ~/.config/acp/clusters.yaml)"
echo "3. Bearer token is valid and not expired"
echo ""
echo "Example clusters.yaml:"
echo "---"
echo "clusters:"
echo "  my-cluster:"
echo "    server: https://public-api-ambient.apps.cluster.example.com"
echo "    token: your-bearer-token-here"
echo "    default_project: my-workspace"
echo ""
echo "default_cluster: my-cluster"
echo "---"
