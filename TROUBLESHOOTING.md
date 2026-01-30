# Troubleshooting Guide

Common issues and solutions.

---

## Installation Issues

### "command not found: mcp-acp"

**Cause**: Python user bin directory not in PATH

**Check**:
```bash
python3 -c "import site; print(site.USER_BASE + '/bin')"
```

**Fix**:
```bash
# macOS (bash)
echo 'export PATH="$HOME/Library/Python/3.11/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile

# macOS (zsh)
echo 'export PATH="$HOME/Library/Python/3.11/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Linux
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### "spawn mcp-acp ENOENT" in Claude Desktop

**Cause**: Claude Desktop can't find mcp-acp in PATH

**Fix 1**: Use absolute path in Claude config

Find installation:
```bash
which mcp-acp
# Or: find ~ -name mcp-acp -type f 2>/dev/null
```

Edit `~/.claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "acp": {
      "command": "/full/path/to/mcp-acp"
    }
  }
}
```

**Fix 2**: Use uvx (bypasses PATH)
```bash
claude mcp add --scope user acp -- \
  uvx --from /path/to/mcp_acp-0.1.0-py3-none-any.whl mcp-acp
```

### "Failed to connect" in Claude Desktop

**Check status**:
```bash
claude mcp list
# Should show: acp - ✓ Connected
```

**Fix**:
1. Restart Claude Desktop
2. Check logs: Look in Claude Desktop output for errors
3. Test server manually:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | mcp-acp
   ```

### uvx cache issues (wrong version loaded)

**Symptom**: Old version still running after update

**Fix**:
```bash
# Clear cache
rm -rf ~/.cache/uv

# Reconfigure
claude mcp add --scope user acp -- \
  uvx --from $(pwd)/mcp_acp-0.1.0-py3-none-any.whl mcp-acp
```

---

## Configuration Issues

### "invalid oauth error response 404"

**Cause**: Not authenticated to OpenShift

**Fix**:
```bash
# Login to cluster
oc login --server=https://api.your-cluster.example.com:6443

# Verify
oc whoami
```

### "Project parameter required" (even with default_project set)

**Cause**: Likely using old version or config not loaded

**Check config**:
```bash
cat ~/.config/acp/clusters.yaml
```

Should have:
```yaml
clusters:
  my-cluster:
    server: https://...
    default_project: my-workspace  # This line required
```

**Fix**: Ensure default_project is set, then restart Claude Desktop

### "Cluster configuration not found"

**Check config exists**:
```bash
ls -la ~/.config/acp/clusters.yaml
```

**Fix**: Create config
```bash
mkdir -p ~/.config/acp
cp clusters.yaml.example ~/.config/acp/clusters.yaml
nano ~/.config/acp/clusters.yaml
```

---

## Authentication Issues

### "User 'X' does not have permission..."

**Cause**: Insufficient RBAC permissions

**Check permissions**:
```bash
oc auth can-i get agenticsession -n my-workspace
oc auth can-i list agenticsession -n my-workspace
```

**Fix**: Ask cluster admin to grant permissions:
```bash
# Admin runs:
oc adm policy add-role-to-user edit username -n my-workspace
```

### "Token expired"

**Fix**: Re-authenticate
```bash
oc login --server=https://your-cluster:6443
```

### "certificate verify failed"

**Cause**: Self-signed certificates

**Workaround** (not recommended for production):
```bash
oc login --server=https://your-cluster:6443 --insecure-skip-tls-verify
```

---

## Runtime Issues

### "No logs available" / "No transcript available"

**Not an error** - This is normal for:
- Stopped sessions (no active pods)
- New sessions (no data yet)
- Sessions that haven't processed messages

**Verify session status**:
```
Get details for ACP session-name
```

Check `phase` field - "Stopped" or "Pending" explains missing data.

### "No pods found for session"

**Cause**: Session is stopped or hasn't started

**Check status**:
```bash
oc get agenticsession session-name -n my-workspace -o yaml
```

Look for:
- `status.phase`: "Stopped", "Pending", etc.
- `spec.replicas`: If 0, session is stopped

**Fix**: Start/restart session if needed
```
Restart ACP session-name
```

### Server responds slowly

**Causes**:
1. Many sessions in project (slow list operations)
2. Large transcripts (slow retrieval)
3. Network latency to cluster

**Fixes**:
- Use filters: `List running ACP sessions`
- Specify session names directly
- Check network connection to cluster

---

## Claude Desktop Integration

### Keywords not triggering MCP server

**Problem**: Saying "view my workspace" doesn't use ACP server

**Cause**: Missing trigger keywords

**Fix**: Use these keywords:
- **ACP**
- **ambient**
- **AgenticSession**
- **OpenShift**

**Examples**:
```
Show my ACP sessions              ✅
List my AgenticSessions           ✅
Get ambient session details       ✅
view my workspace                 ❌ Too generic
```

**See**: TRIGGER_PHRASES.md for complete list

### MCP server not listed

**Check**:
```bash
claude mcp list
```

**Fix**: Add server
```bash
claude mcp add --scope user acp -- mcp-acp
```

---

## Diagnostic Tools

### Run Full Diagnostics

```bash
./debug-mcp-server.sh
```

Checks:
- Python environment
- mcp-acp installation
- Dependencies
- Cluster configuration
- OpenShift authentication
- MCP protocol
- Claude Desktop config

### Check Configuration

```bash
./check-config.sh
```

Validates clusters.yaml format and required fields.

### Manual MCP Protocol Test

```bash
# Test server responds
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | mcp-acp

# Test list tools
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | mcp-acp
```

### Check OpenShift Access

```bash
# Verify authentication
oc whoami
oc whoami --show-server
oc project -q

# Test access to AgenticSessions
oc get agenticsession -n my-workspace

# Check RBAC
oc auth can-i get agenticsession -n my-workspace
oc auth can-i create agenticsession -n my-workspace
```

---

## Getting Help

### Collect Debug Information

```bash
# Installation info
which mcp-acp
pip show mcp-acp

# Config
cat ~/.config/acp/clusters.yaml

# OpenShift status
oc whoami
oc project -q
oc get agenticsession -n my-workspace

# Claude Desktop config
cat ~/.claude/claude_desktop_config.json 2>/dev/null || \
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json 2>/dev/null
```

### Common Solutions Summary

| Issue | Quick Fix |
|-------|-----------|
| Command not found | Add Python bin to PATH |
| ENOENT in Claude | Use absolute path or uvx |
| Failed to connect | Restart Claude Desktop |
| Invalid oauth | Run `oc login` |
| No permissions | Ask admin for access |
| Old version cached | Clear uvx cache |
| Keywords not working | Use "ACP", "ambient", "AgenticSession" |

---

## Still Having Issues?

1. Run `./debug-mcp-server.sh` for comprehensive diagnostics
2. Check you're using latest version (v0.1.0)
3. Verify OpenShift authentication: `oc whoami`
4. Test server manually: `echo '...' | mcp-acp`
5. Check Claude Desktop logs for error details
