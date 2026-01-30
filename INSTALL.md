# Installation Guide

Complete installation instructions for all platforms.

---

## Prerequisites

- **Python**: 3.10 or higher
- **OpenShift CLI**: `oc` command installed
- **OpenShift Access**: Valid credentials for your cluster

---

## Quick Install (macOS/Linux)

```bash
# Extract distribution
tar -xzf mcp-acp-v0.1.0.tar.gz
cd mcp-acp-v0.1.0

# Run installer
./install-macos-quick.sh

# Configure cluster
cp clusters.yaml.example ~/.config/acp/clusters.yaml
nano ~/.config/acp/clusters.yaml

# Authenticate
oc login --server=https://your-cluster:6443

# Add to Claude Desktop
claude mcp add --scope user acp -- mcp-acp
```

---

## Installation Methods

### Method 1: pip (Recommended)

**Best for**: Most users, stable installation

```bash
# Install
pip install --user mcp_acp-0.1.0-py3-none-any.whl

# Verify
which mcp-acp

# If command not found, add to PATH
echo 'export PATH="$HOME/Library/Python/3.11/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile

# Configure Claude Desktop
claude mcp add --scope user acp -- mcp-acp
```

### Method 2: uvx (Fastest)

**Best for**: Isolated environments, no PATH issues

```bash
# Clear cache
rm -rf ~/.cache/uv

# Configure with local wheel
claude mcp add --scope user acp -- \
  uvx --from $(pwd)/mcp_acp-0.1.0-py3-none-any.whl mcp-acp

# Or with installed package
claude mcp add --scope user acp -- uvx mcp-acp
```

### Method 3: Development Install

**Best for**: Contributing, testing changes

```bash
# Clone/extract source
cd mcp-acp-source

# Install in editable mode
pip install -e .

# Configure
claude mcp add --scope user acp -- mcp-acp
```

---

## Configuration

### 1. Cluster Configuration

Create `~/.config/acp/clusters.yaml`:

```yaml
clusters:
  my-cluster:
    server: https://api.your-cluster.example.com:6443
    description: "My OpenShift Cluster"
    default_project: my-workspace

default_cluster: my-cluster
```

**Required fields**:
- `server`: OpenShift API URL
- `default_project`: Your default namespace

### 2. OpenShift Authentication

```bash
# Login
oc login --server=https://your-cluster:6443

# Verify
oc whoami
oc project my-workspace
```

### 3. Claude Desktop Configuration

```bash
# Add MCP server
claude mcp add --scope user acp -- mcp-acp

# Verify
claude mcp list
# Should show: acp - ✓ Connected
```

---

## Verification

### Test Installation

```bash
# Test command exists
which mcp-acp

# Test server runs
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | mcp-acp
```

### Test in Claude Desktop

```
Use acp_whoami to check my authentication
```

**Expected output**:
```
Current Authentication Status:

Authenticated: Yes
User: your-username
Cluster: my-cluster
Server: https://your-cluster:6443
Project: my-workspace
Token Valid: Yes
```

---

## Platform-Specific Notes

### macOS

**PATH issues**: Python user packages install to `~/Library/Python/3.x/bin`

Add to `~/.bash_profile` or `~/.zshrc`:
```bash
export PATH="$HOME/Library/Python/3.11/bin:$PATH"
```

**OpenShift CLI**: Install with Homebrew
```bash
brew install openshift-cli
```

### Linux

**PATH issues**: User packages install to `~/.local/bin`

Add to `~/.bashrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**OpenShift CLI**: Download from OpenShift downloads page

### Windows (WSL)

Use WSL2 with Ubuntu and follow Linux instructions.

---

## Updating

### Update Existing Installation

```bash
# pip users
pip install --force-reinstall mcp_acp-0.1.0-py3-none-any.whl

# uvx users
rm -rf ~/.cache/uv
claude mcp add --scope user acp -- \
  uvx --from /path/to/new/mcp_acp-0.1.0-py3-none-any.whl mcp-acp
```

**No config changes needed** - clusters.yaml stays the same

---

## Troubleshooting

### "command not found: mcp-acp"

**Cause**: Not in PATH

**Fix**:
```bash
# Find installation
python3 -c "import site; print(site.USER_BASE + '/bin')"

# Add to PATH
export PATH="$(python3 -c 'import site; print(site.USER_BASE + "/bin")'):$PATH"
```

### "spawn mcp-acp ENOENT" in Claude Desktop

**Cause**: Claude Desktop can't find command

**Fix**: Use absolute path in config
```json
{
  "mcpServers": {
    "acp": {
      "command": "/full/path/to/mcp-acp"
    }
  }
}
```

### "Failed to connect" in Claude Desktop

**Fix**: Check server status
```bash
claude mcp list
# Should show: acp - ✓ Connected

# If not connected, restart Claude Desktop
```

### "invalid oauth error response 404"

**Cause**: Not authenticated to OpenShift

**Fix**:
```bash
oc login --server=https://your-cluster:6443
```

### uvx cache issues

**Fix**:
```bash
rm -rf ~/.cache/uv
# Then reconfigure Claude Desktop
```

**See**: TROUBLESHOOTING.md for complete guide

---

## Next Steps

1. ✅ Install package
2. ✅ Configure cluster
3. ✅ Authenticate to OpenShift
4. ✅ Add to Claude Desktop
5. 📖 Read QUICKSTART.md for usage examples
6. 📚 See API_REFERENCE.md for all tools
