#!/bin/bash
# MCP ACP Server Debug Script

echo "=== MCP ACP Server Diagnostic ===="
echo ""

# Check Python
echo "1. Python Environment:"
echo "   Python version: $(python --version 2>&1)"
echo "   Python location: $(which python)"
echo "   pip version: $(pip --version 2>&1)"
echo ""

# Check if mcp-acp is installed
echo "2. MCP ACP Installation:"
if command -v mcp-acp &> /dev/null; then
    echo "   ✓ mcp-acp command found: $(which mcp-acp)"
    echo "   Package info:"
    pip show mcp-acp 2>&1 | grep -E "(Name|Version|Location)"
else
    echo "   ✗ mcp-acp command not found"
fi
echo ""

# Check wheel file
echo "3. Wheel File:"
WHEEL_PATH="$HOME/repos/mcp-acp/mcp-acp-v0.1.0/mcp_acp-0.1.0-py3-none-any.whl"
if [ -f "$WHEEL_PATH" ]; then
    echo "   ✓ Wheel exists: $WHEEL_PATH"
    echo "   Size: $(ls -lh "$WHEEL_PATH" | awk '{print $5}')"
    echo "   Modified: $(ls -l "$WHEEL_PATH" | awk '{print $6, $7, $8}')"
    echo "   Shasum: $(shasum "$WHEEL_PATH" | awk '{print $1}')"

    # Check entry point
    echo ""
    echo "   Entry point in wheel:"
    unzip -p "$WHEEL_PATH" mcp_acp-0.1.0.dist-info/entry_points.txt 2>/dev/null || echo "   ✗ Could not extract entry_points.txt"
else
    echo "   ✗ Wheel not found at: $WHEEL_PATH"
fi
echo ""

# Check dependencies
echo "4. Dependencies:"
for pkg in mcp pydantic aiohttp pyyaml python-dateutil; do
    if pip show $pkg &> /dev/null; then
        VERSION=$(pip show $pkg 2>/dev/null | grep Version | awk '{print $2}')
        echo "   ✓ $pkg ($VERSION)"
    else
        echo "   ✗ $pkg (not installed)"
    fi
done
echo ""

# Test direct Python import
echo "5. Direct Python Import Test:"
python3 << 'PYEOF'
try:
    import sys
    print(f"   Python path: {sys.executable}")

    # Try importing the package
    import mcp_acp
    print(f"   ✓ mcp_acp imported successfully")
    print(f"   Version: {mcp_acp.__version__}")
    print(f"   Location: {mcp_acp.__file__}")

    # Try importing server
    from mcp_acp.server import run, main
    print(f"   ✓ server.run imported successfully")
    print(f"   ✓ server.main imported successfully")

except ImportError as e:
    print(f"   ✗ Import failed: {e}")
except Exception as e:
    print(f"   ✗ Error: {e}")
PYEOF
echo ""

# Test running the server
echo "6. Server Execution Test:"
echo "   Testing: echo test | mcp-acp (timeout 2s)"
if command -v mcp-acp &> /dev/null; then
    timeout 2 sh -c 'echo "test" | mcp-acp' 2>&1 | head -5
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo "   ✓ Server started (timed out waiting for input - this is good)"
    elif [ $EXIT_CODE -eq 0 ]; then
        echo "   ⚠ Server exited immediately (may be okay)"
    else
        echo "   ✗ Server failed with exit code: $EXIT_CODE"
    fi
else
    echo "   ✗ Cannot test - mcp-acp not in PATH"
fi
echo ""

# Test MCP protocol
echo "7. MCP Protocol Test:"
echo "   Sending initialize message..."
if command -v mcp-acp &> /dev/null; then
    RESPONSE=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | timeout 5 mcp-acp 2>&1)
    if echo "$RESPONSE" | grep -q "jsonrpc"; then
        echo "   ✓ Got JSON-RPC response"
        echo "$RESPONSE" | python3 -m json.tool 2>/dev/null | head -10
    else
        echo "   ✗ No valid response. Output:"
        echo "$RESPONSE" | head -10
    fi
else
    echo "   ✗ Cannot test - mcp-acp not in PATH"
fi
echo ""

# Check Claude Code config
echo "8. Claude Code Configuration:"
CLAUDE_CONFIG="$HOME/.claude.json"
if [ -f "$CLAUDE_CONFIG" ]; then
    echo "   ✓ Config found: $CLAUDE_CONFIG"
    if grep -q '"acp"' "$CLAUDE_CONFIG" 2>/dev/null; then
        echo "   ACP server config:"
        grep -A 10 '"acp"' "$CLAUDE_CONFIG" | head -15
    else
        echo "   ⚠ No 'acp' server configured"
    fi
else
    echo "   ✗ No config file at: $CLAUDE_CONFIG"
fi
echo ""

# Check cluster config
echo "9. Cluster Configuration:"
CLUSTER_CONFIG="$HOME/.config/acp/clusters.yaml"
if [ -f "$CLUSTER_CONFIG" ]; then
    echo "   ✓ Config found: $CLUSTER_CONFIG"
    echo "   Contents:"
    head -20 "$CLUSTER_CONFIG" | sed 's/^/   /'
else
    echo "   ✗ No cluster config at: $CLUSTER_CONFIG"
fi
echo ""

# Check OpenShift authentication
echo "10. OpenShift Authentication:"
if command -v oc &> /dev/null; then
    echo "   ✓ oc command found: $(which oc)"
    echo "   oc version: $(oc version --client 2>&1 | head -1)"

    # Try whoami
    if oc whoami &> /dev/null; then
        echo "   ✓ Authenticated as: $(oc whoami)"
        echo "   Current project: $(oc project -q 2>/dev/null || echo 'none')"
    else
        echo "   ✗ Not authenticated to OpenShift"
    fi
else
    echo "   ✗ oc command not found"
fi
echo ""

echo "=== End Diagnostic ==="
echo ""
echo "Next steps:"
echo "1. If mcp-acp is not installed, run:"
echo "   pip install $HOME/repos/mcp-acp/mcp-acp-v0.1.0/mcp_acp-0.1.0-py3-none-any.whl"
echo ""
echo "2. If dependencies are missing, run:"
echo "   pip install 'mcp>=1.0.0' 'pydantic>=2.0.0' 'aiohttp>=3.8.0' 'pyyaml>=6.0' 'python-dateutil>=2.8.0'"
echo ""
echo "3. If cluster config is missing, run:"
echo "   mkdir -p ~/.config/acp && cp $HOME/repos/mcp-acp/mcp-acp-v0.1.0/clusters.yaml.example ~/.config/acp/clusters.yaml"
echo ""
echo "4. If not authenticated, run:"
echo "   oc login --server=https://your-cluster:6443"
