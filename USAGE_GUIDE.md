# MCP ACP Server - Usage Guide

Complete guide to installing, configuring, and using the MCP ACP Server.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Basic Usage](#basic-usage)
5. [Filtering and Querying](#filtering-and-querying)
6. [Session Management](#session-management)
7. [Bulk Operations](#bulk-operations)
8. [Debugging](#debugging)
9. [Cluster Management](#cluster-management)
10. [Workflow Examples](#workflow-examples)
11. [Best Practices](#best-practices)
12. [Troubleshooting](#troubleshooting)

---

## Quick Start

Get up and running with MCP ACP Server in 5 minutes.

### Prerequisites

- Python 3.10+
- OpenShift CLI (`oc`) installed
- Access to an OpenShift cluster with ACP

### Installation

```bash
pip install mcp-acp
```

### Configuration

#### 1. Create Cluster Config

```bash
mkdir -p ~/.config/acp
cat > ~/.config/acp/clusters.yaml <<EOF
clusters:
  my-cluster:
    server: https://api.your-cluster.example.com:443
    description: "My OpenShift Cluster"
    default_project: my-workspace

default_cluster: my-cluster
EOF
```

#### 2. Configure MCP Client

For Claude Desktop, edit config file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "acp": {
      "command": "mcp-acp"
    }
  }
}
```

#### 3. Authenticate

```bash
oc login --server=https://api.your-cluster.example.com:443
```

### First Commands

#### Check Authentication

```
Use acp_whoami to check my authentication
```

#### List Sessions

```
List all sessions in my-workspace project
```

#### Filter Sessions

```
List running sessions in my-workspace
```

#### Delete with Dry-Run

```
Delete session-name from my-workspace in dry-run mode first
```

---

## Installation

### Method 1: Install from PyPI (when published)

```bash
pip install mcp-acp
```

### Method 2: Install from Source

```bash
# Clone the repository
git clone <repository-url>
cd mcp-acp

# Install in development mode
pip install -e .

# Or install normally
pip install .
```

### Method 3: Install with Development Dependencies

```bash
pip install -e ".[dev]"
```

### Verification

Test the installation:

```bash
# Check that mcp-acp is installed
which mcp-acp

# Test the server (will start in stdio mode)
mcp-acp
```

Test with MCP Client (Claude Desktop):

1. Restart Claude Desktop
2. Check that the ACP tools are available
3. Try a simple command:
   ```
   Use acp_whoami to check my authentication status
   ```

---

## Configuration

### Cluster Configuration File

Create a configuration file at `~/.config/acp/clusters.yaml`:

```yaml
clusters:
  vteam-stage:
    server: https://api.vteam-stage.7fpc.p3.openshiftapps.com:443
    description: "V-Team Staging Environment"
    default_project: jeder-workspace

  vteam-prod:
    server: https://api.vteam-prod.xxxx.p3.openshiftapps.com:443
    description: "V-Team Production"
    default_project: jeder-workspace

default_cluster: vteam-stage
```

**Security Note:** This file should only contain cluster metadata. Authentication is handled separately via `oc login`.

### Environment Variables

The following environment variables can be configured:

- `ACP_CLUSTER_CONFIG`: Path to clusters.yaml config file (default: `~/.config/acp/clusters.yaml`)

### Authenticate with OpenShift

Before using the MCP server, authenticate with your OpenShift cluster:

```bash
oc login --server=https://api.your-cluster.example.com:443 --token=your-token
```

Or use web authentication:

```bash
oc login --web --server=https://api.your-cluster.example.com:443
```

---

## Basic Usage

### Check Authentication Status

```python
# Check your current authentication
acp_whoami()
```

**Output:**
```
Current Authentication Status:

Authenticated: Yes
User: jeder
Server: https://api.vteam-stage.7fpc.p3.openshiftapps.com:443
Project: jeder-workspace
Token Valid: Yes
```

### List All Sessions

```python
# List all sessions in a project
acp_list_sessions(project="jeder-workspace")
```

**Output:**
```
Found 5 session(s)

Sessions:

- session-1 ("Debug PR-123")
  Status: running
  Created: 2024-01-25T10:30:00Z

- session-2
  Status: stopped
  Created: 2024-01-24T08:15:00Z
...
```

---

## Filtering and Querying

### Filter by Status

```python
# List only running sessions
acp_list_sessions(project="jeder-workspace", status="running")

# List only stopped sessions
acp_list_sessions(project="jeder-workspace", status="stopped")

# List failed sessions
acp_list_sessions(project="jeder-workspace", status="failed")
```

### Filter by Age

```python
# List sessions older than 7 days
acp_list_sessions(project="jeder-workspace", older_than="7d")

# List sessions older than 24 hours
acp_list_sessions(project="jeder-workspace", older_than="24h")

# List sessions older than 30 minutes
acp_list_sessions(project="jeder-workspace", older_than="30m")
```

### Filter by Display Name

```python
# List sessions that have a display name
acp_list_sessions(project="jeder-workspace", has_display_name=True)

# List sessions without a display name
acp_list_sessions(project="jeder-workspace", has_display_name=False)
```

### Sorting

```python
# Sort by creation time (newest first)
acp_list_sessions(project="jeder-workspace", sort_by="created")

# Sort by stop time
acp_list_sessions(project="jeder-workspace", sort_by="stopped")

# Sort by name
acp_list_sessions(project="jeder-workspace", sort_by="name")
```

### Combined Filters

```python
# Find old stopped sessions without display names
acp_list_sessions(
    project="jeder-workspace",
    status="stopped",
    has_display_name=False,
    older_than="7d",
    sort_by="created",
    limit=10
)
```

---

## Session Management

### Dry-Run Mode

All mutating operations support dry-run mode for safe preview before execution.

#### Preview Session Deletion

```python
# Preview what would be deleted
result = acp_delete_session(
    project="jeder-workspace",
    session="old-session",
    dry_run=True
)
```

**Output:**
```
DRY RUN MODE - No changes made

Would delete session 'old-session' in project 'jeder-workspace'

Session Info:
{
  "name": "old-session",
  "status": "stopped",
  "created": "2024-01-15T10:00:00Z"
}
```

#### Preview Session Restart

```python
# Preview session restart
result = acp_restart_session(
    project="jeder-workspace",
    session="my-session",
    dry_run=True
)
```

**Output:**
```
DRY RUN MODE - No changes made

Would restart session 'my-session' (current status: stopped)

Session Info:
{
  "name": "my-session",
  "current_status": "stopped",
  "stopped_at": "2024-01-28T15:30:00Z"
}
```

### Delete a Session

```python
# Delete a single session
acp_delete_session(project="jeder-workspace", session="old-session")
```

**Output:**
```
Successfully deleted session 'old-session' from project 'jeder-workspace'
```

### Restart a Session

```python
# Restart a stopped session
acp_restart_session(project="jeder-workspace", session="my-session")
```

**Output:**
```
Successfully restarted session 'my-session' in project 'jeder-workspace'
```

---

## Bulk Operations

### Bulk Delete Sessions

```python
# Delete multiple sessions at once
acp_bulk_delete_sessions(
    project="jeder-workspace",
    sessions=["old-session-1", "old-session-2", "old-session-3"]
)
```

**Output:**
```
Successfully deleted 3 session(s):
  - old-session-1
  - old-session-2
  - old-session-3
```

### Bulk Delete with Failures

```python
# Some sessions might not exist
acp_bulk_delete_sessions(
    project="jeder-workspace",
    sessions=["session-1", "nonexistent", "session-2"]
)
```

**Output:**
```
Successfully deleted 2 session(s):
  - session-1
  - session-2

Failed (1 session(s)):
  - nonexistent: Session not found
```

### Bulk Stop Sessions

```python
# Stop multiple running sessions
acp_bulk_stop_sessions(
    project="jeder-workspace",
    sessions=["session-1", "session-2", "session-3"]
)
```

**Output:**
```
Successfully stopped 3 session(s):
  - session-1
  - session-2
  - session-3
```

### Preview Bulk Operations

```python
# Preview bulk deletion
result = acp_bulk_delete_sessions(
    project="jeder-workspace",
    sessions=["session-1", "session-2", "session-3"],
    dry_run=True
)
```

**Output:**
```
DRY RUN MODE - No changes made

Would delete 2 session(s):
  - session-1
  - session-2

Not found (1 session(s)):
  - session-3
```

---

## Debugging

### Get Session Logs

```python
# Get logs from default container
acp_get_session_logs(
    project="jeder-workspace",
    session="debug-session"
)

# Get logs from specific container
acp_get_session_logs(
    project="jeder-workspace",
    session="debug-session",
    container="runner"
)

# Get last 100 lines
acp_get_session_logs(
    project="jeder-workspace",
    session="debug-session",
    container="runner",
    tail_lines=100
)
```

**Output:**
```
Logs from container 'runner' (156 lines):

2024-01-28 10:00:00 INFO Starting session runner
2024-01-28 10:00:01 INFO Loading configuration
2024-01-28 10:00:02 INFO Connecting to LLM endpoint
2024-01-28 10:00:05 INFO Session ready
...
```

---

## Cluster Management

### List Configured Clusters

```python
# List all configured clusters
acp_list_clusters()
```

**Output:**
```
Configured Clusters (default: vteam-stage):

- vteam-stage [DEFAULT]
  Server: https://api.vteam-stage.7fpc.p3.openshiftapps.com:443
  Description: V-Team Staging Environment
  Default Project: jeder-workspace

- vteam-prod
  Server: https://api.vteam-prod.xxxx.p3.openshiftapps.com:443
  Description: V-Team Production
  Default Project: jeder-workspace
```

---

## Workflow Examples

### Cleanup Old Sessions

```python
# 1. Find old stopped sessions
result = acp_list_sessions(
    project="jeder-workspace",
    status="stopped",
    older_than="7d"
)

# 2. Preview deletion
session_names = [s["metadata"]["name"] for s in result["sessions"]]
acp_bulk_delete_sessions(
    project="jeder-workspace",
    sessions=session_names,
    dry_run=True
)

# 3. Actually delete
acp_bulk_delete_sessions(
    project="jeder-workspace",
    sessions=session_names
)
```

### Debug a Failed Session

```python
# 1. List failed sessions
failed = acp_list_sessions(
    project="jeder-workspace",
    status="failed"
)

# 2. Get logs for investigation
for session in failed["sessions"]:
    session_name = session["metadata"]["name"]
    acp_get_session_logs(
        project="jeder-workspace",
        session=session_name,
        tail_lines=200
    )
```

### Restart All Stopped Sessions

```python
# 1. Find stopped sessions
stopped = acp_list_sessions(
    project="jeder-workspace",
    status="stopped"
)

# 2. Restart each one
for session in stopped["sessions"]:
    session_name = session["metadata"]["name"]
    acp_restart_session(
        project="jeder-workspace",
        session=session_name
    )
```

### Clean Up Sessions Without Display Names

```python
# 1. Find sessions without display names
unnamed = acp_list_sessions(
    project="jeder-workspace",
    has_display_name=False,
    older_than="3d"
)

# 2. Preview deletion
session_names = [s["metadata"]["name"] for s in unnamed["sessions"]]
acp_bulk_delete_sessions(
    project="jeder-workspace",
    sessions=session_names,
    dry_run=True
)

# 3. Delete if appropriate
acp_bulk_delete_sessions(
    project="jeder-workspace",
    sessions=session_names
)
```

---

## Best Practices

### Always Use Dry-Run First

For any destructive operation, use dry-run mode first:

```python
# WRONG: Direct deletion
acp_delete_session(project="my-project", session="my-session")

# RIGHT: Preview first
acp_delete_session(project="my-project", session="my-session", dry_run=True)
# Review output, then:
acp_delete_session(project="my-project", session="my-session")
```

### Use Filters to Target Specific Sessions

Don't list all sessions and filter manually. Use server-side filters:

```python
# WRONG: List all and filter client-side
all_sessions = acp_list_sessions(project="my-project")
old_stopped = [s for s in all_sessions["sessions"]
               if s["status"]["phase"] == "stopped" and is_old(s)]

# RIGHT: Use server-side filters
old_stopped = acp_list_sessions(
    project="my-project",
    status="stopped",
    older_than="7d"
)
```

### Verify Authentication Before Operations

```python
# Check authentication first
auth = acp_whoami()
if not auth["authenticated"]:
    print("Please run: oc login")
    exit(1)

# Proceed with operations
acp_list_sessions(project="my-workspace")
```

### Use Bulk Operations for Efficiency

```python
# WRONG: Delete sessions one by one
for session in old_sessions:
    acp_delete_session(project="my-project", session=session)

# RIGHT: Use bulk delete
acp_bulk_delete_sessions(project="my-project", sessions=old_sessions)
```

### Safety Tips

1. **Always dry-run first** for destructive operations
2. **Test filters** before bulk operations
3. **Check authentication** before starting work
4. **Use specific filters** to avoid unintended changes

---

## Troubleshooting

### "oc: command not found"

Install the OpenShift CLI:

- **macOS**: `brew install openshift-cli`
- **Linux**: Download from [OpenShift releases](https://github.com/openshift/okd/releases)
- **Windows**: Download from [OpenShift releases](https://github.com/openshift/okd/releases)

### "Authentication required"

Run `oc login` to authenticate:

```bash
oc login --server=https://api.your-cluster.example.com:443
```

### "Permission denied" on clusters.yaml

Ensure the config directory has proper permissions:

```bash
chmod 755 ~/.config/acp
chmod 644 ~/.config/acp/clusters.yaml
```

### MCP Server Not Showing Up

1. Check Claude Desktop logs (Help → View Logs)
2. Verify the config file syntax is valid JSON
3. Restart Claude Desktop completely
4. Check that `mcp-acp` is in your PATH

### Tool Calls Failing

1. Verify authentication: `oc whoami`
2. Check project access: `oc projects`
3. Verify session exists: `oc get agenticsession -n <project>`
4. Check MCP server logs for errors

### Getting Help

If something isn't working:

1. Check `oc whoami` - are you authenticated?
2. Check `oc get agenticsession -n <project>` - do sessions exist?
3. Check MCP client logs for errors
4. Verify `mcp-acp` is in your PATH

---

## Common Task Cheat Sheet

| Task | Command Pattern |
|------|----------------|
| Check auth | `acp_whoami()` |
| List all | `acp_list_sessions(project="...")` |
| Filter by status | `acp_list_sessions(project="...", status="running")` |
| Filter by age | `acp_list_sessions(project="...", older_than="7d")` |
| Delete (dry) | `acp_delete_session(project="...", session="...", dry_run=True)` |
| Delete (real) | `acp_delete_session(project="...", session="...")` |
| Restart | `acp_restart_session(project="...", session="...")` |
| Get logs | `acp_get_session_logs(project="...", session="...")` |
| List clusters | `acp_list_clusters()` |

---

## Uninstallation

```bash
pip uninstall mcp-acp
```

Remove configuration files (optional):

```bash
rm -rf ~/.config/acp
```

---

## Next Steps

- Read the [API Reference](API_REFERENCE.md) for complete tool specifications
- Check [SECURITY.md](SECURITY.md) for security features and best practices
- See [ARCHITECTURE.md](ARCHITECTURE.md) for system design details
- Review [DEVELOPMENT.md](DEVELOPMENT.md) for contributing guidelines

Happy session management!
