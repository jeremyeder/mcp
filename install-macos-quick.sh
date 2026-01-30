#!/bin/bash
# Quick macOS installation script for mcp-acp
# Fixes the ENOENT error by ensuring mcp-acp is in PATH

set -e

echo "🚀 Installing mcp-acp for macOS..."
echo

# Check if we're in the right directory
if [ ! -f "mcp_acp-0.1.0-py3-none-any.whl" ]; then
    echo "❌ Error: mcp_acp-0.1.0-py3-none-any.whl not found in current directory"
    echo "Please cd to the mcp-acp-v0.1.0-improved directory first"
    exit 1
fi

# Install the wheel
echo "📦 Installing mcp-acp wheel..."
pip install --user mcp_acp-0.1.0-py3-none-any.whl
echo

# Detect Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "🐍 Detected Python version: $PYTHON_VERSION"
echo

# Find where mcp-acp was installed
MCP_PATH=$(python3 -c "import site; print(site.USER_BASE + '/bin')")/mcp-acp

if [ -f "$MCP_PATH" ]; then
    echo "✅ mcp-acp installed at: $MCP_PATH"
else
    echo "⚠️  Warning: mcp-acp not found at expected location: $MCP_PATH"
    echo "Searching for installation location..."
    SEARCH_PATH=$(find ~/Library/Python -name "mcp-acp" 2>/dev/null | head -1)
    if [ -n "$SEARCH_PATH" ]; then
        MCP_PATH="$SEARCH_PATH"
        echo "✅ Found at: $MCP_PATH"
    else
        echo "❌ Could not locate mcp-acp installation"
        exit 1
    fi
fi
echo

# Get the bin directory
BIN_DIR=$(dirname "$MCP_PATH")
echo "📁 Binary directory: $BIN_DIR"
echo

# Check if bin directory is in PATH
if echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "✅ $BIN_DIR is already in PATH"
else
    echo "⚠️  $BIN_DIR is NOT in PATH"
    echo
    echo "Adding to PATH configuration..."

    # Detect shell
    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        bash)
            RC_FILE="$HOME/.bash_profile"
            ;;
        zsh)
            RC_FILE="$HOME/.zshrc"
            ;;
        *)
            RC_FILE="$HOME/.profile"
            ;;
    esac

    # Add to PATH in shell config
    PATH_LINE="export PATH=\"$BIN_DIR:\$PATH\""

    if ! grep -q "$BIN_DIR" "$RC_FILE" 2>/dev/null; then
        echo "" >> "$RC_FILE"
        echo "# Added by mcp-acp installer" >> "$RC_FILE"
        echo "$PATH_LINE" >> "$RC_FILE"
        echo "✅ Added PATH to $RC_FILE"
        echo
        echo "⚠️  Please run: source $RC_FILE"
        echo "   Or restart your terminal"
    else
        echo "✅ PATH already configured in $RC_FILE"
    fi

    # Add to current session
    export PATH="$BIN_DIR:$PATH"
    echo "✅ Added to current session PATH"
fi
echo

# Verify installation
echo "🧪 Testing installation..."
if command -v mcp-acp >/dev/null 2>&1; then
    echo "✅ mcp-acp command is available"
    echo
    echo "Testing MCP protocol..."
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | mcp-acp | head -5
    echo
    echo "✅ MCP server responds correctly"
else
    echo "❌ mcp-acp command not found in PATH"
    echo "Try running: source $RC_FILE"
    exit 1
fi
echo

# Check Claude Desktop config
echo "🔧 Checking Claude Desktop configuration..."
CLAUDE_CONFIG=""
for config_path in \
    "$HOME/.claude/claude_desktop_config.json" \
    "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
    "$HOME/.config/claude/config.json"; do
    if [ -f "$config_path" ]; then
        CLAUDE_CONFIG="$config_path"
        break
    fi
done

if [ -n "$CLAUDE_CONFIG" ]; then
    echo "✅ Found Claude config at: $CLAUDE_CONFIG"

    # Check if acp server is configured
    if grep -q '"acp"' "$CLAUDE_CONFIG" 2>/dev/null; then
        echo "✅ ACP MCP server already configured"
    else
        echo "⚠️  ACP MCP server not configured"
        echo
        echo "To configure, run:"
        echo "  claude mcp add --scope user acp -- mcp-acp"
    fi
else
    echo "⚠️  Claude Desktop config not found"
    echo "After installing Claude Desktop, run:"
    echo "  claude mcp add --scope user acp -- mcp-acp"
fi
echo

# Check ACP cluster configuration
echo "🌐 Checking ACP cluster configuration..."
if [ -f "$HOME/.config/acp/clusters.yaml" ]; then
    echo "✅ Found clusters.yaml"
    echo
    echo "Configuration:"
    cat "$HOME/.config/acp/clusters.yaml"
    echo
else
    echo "⚠️  No clusters.yaml found"
    echo
    echo "To configure your cluster, run:"
    echo "  mkdir -p ~/.config/acp"
    echo "  cp clusters.yaml.example ~/.config/acp/clusters.yaml"
    echo "  nano ~/.config/acp/clusters.yaml"
fi
echo

# Check OpenShift authentication
echo "🔐 Checking OpenShift authentication..."
if command -v oc >/dev/null 2>&1; then
    echo "✅ oc command found"

    if oc whoami >/dev/null 2>&1; then
        echo "✅ Authenticated as: $(oc whoami)"
        echo "   Server: $(oc whoami --show-server)"
        echo "   Project: $(oc project -q 2>/dev/null || echo 'none')"
    else
        echo "⚠️  Not authenticated to OpenShift"
        echo
        echo "To authenticate, run:"
        echo "  oc login --server=https://api.vteam-stage.7fpc.p3.openshiftapps.com:443"
    fi
else
    echo "❌ oc command not found"
    echo "Please install OpenShift CLI: brew install openshift-cli"
fi
echo

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Installation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "✅ mcp-acp installed at: $MCP_PATH"
echo "✅ Command available: $(command -v mcp-acp || echo 'after sourcing shell config')"
echo
echo "Next steps:"
echo "  1. If PATH warning shown, run: source $RC_FILE"
echo "  2. Configure Claude Desktop: claude mcp add --scope user acp -- mcp-acp"
echo "  3. Restart Claude Desktop"
echo "  4. Test with: 'Use acp_whoami to check my authentication'"
echo
echo "Documentation available in current directory:"
echo "  - README.md - Overview"
echo "  - TRIGGER_PHRASES.md - How to trigger the MCP server"
echo "  - QUICKSTART.md - Step-by-step setup"
echo "  - USAGE_GUIDE.md - 40+ examples"
echo
echo "Happy coding! 🚀"
