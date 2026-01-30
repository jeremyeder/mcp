# ACP MCP Server - API Reference

Complete reference for all 19 tools available in the ACP MCP Server.

---

## Table of Contents

1. [Priority 0 Tools (Critical)](#priority-0-tools-critical)
   - [acp_list_sessions](#acp_list_sessions)
   - [acp_delete_session](#acp_delete_session)

2. [Priority 1 Tools (Important)](#priority-1-tools-important)
   - [acp_restart_session](#acp_restart_session)
   - [acp_bulk_delete_sessions](#acp_bulk_delete_sessions)
   - [acp_bulk_stop_sessions](#acp_bulk_stop_sessions)
   - [acp_get_session_logs](#acp_get_session_logs)
   - [acp_list_clusters](#acp_list_clusters)
   - [acp_whoami](#acp_whoami)

3. [Priority 2 Tools (Power Users)](#priority-2-tools-power-users)
   - [acp_clone_session](#acp_clone_session)
   - [acp_get_session_transcript](#acp_get_session_transcript)
   - [acp_update_session](#acp_update_session)
   - [acp_export_session](#acp_export_session)

4. [Priority 3 Tools (Advanced)](#priority-3-tools-advanced)
   - [acp_get_session_metrics](#acp_get_session_metrics)
   - [acp_list_workflows](#acp_list_workflows)
   - [acp_create_session_from_template](#acp_create_session_from_template)

5. [Authentication Tools](#authentication-tools)
   - [acp_login](#acp_login)
   - [acp_switch_cluster](#acp_switch_cluster)
   - [acp_add_cluster](#acp_add_cluster)

---

## Priority 0 Tools (Critical)

### acp_list_sessions

List sessions with advanced filtering, sorting, and limiting.

**Input Schema:**
```json
{
  "project": "string (required)",
  "status": "string (optional) - running|stopped|creating|failed",
  "has_display_name": "boolean (optional)",
  "older_than": "string (optional) - e.g., '7d', '24h', '30m'",
  "sort_by": "string (optional) - created|stopped|name",
  "limit": "integer (optional)"
}
```

**Output:**
```json
{
  "sessions": [
    {
      "metadata": {"name": "...", "creationTimestamp": "..."},
      "spec": {"displayName": "...", "stopped": false},
      "status": {"phase": "running", "stoppedAt": null}
    }
  ],
  "total": 10,
  "filters_applied": {"status": "running", "limit": 10}
}
```

**Behavior:**
- Build filter predicates based on parameters
- Single-pass filtering: `all(f(s) for f in filters)`
- Sort results if `sort_by` specified (reverse for created/stopped, normal for name)
- Apply limit after filtering and sorting
- Return metadata about filters applied

**Implementation Notes:**
- Parse time deltas: `(\d+)([dhm])` → timedelta
- Compare timestamps after converting to timezone-naive UTC
- Default sort: no sorting (insertion order from API)

---

### acp_delete_session

Delete a session with optional dry-run.

**Input Schema:**
```json
{
  "project": "string (required)",
  "session": "string (required)",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "deleted": true,
  "message": "Successfully deleted session 'foo' from project 'bar'",
  "dry_run": false
}
```

**Dry-Run Output:**
```json
{
  "dry_run": true,
  "success": true,
  "message": "Would delete session 'foo' in project 'bar'",
  "session_info": {
    "name": "foo",
    "status": "running",
    "created": "2026-01-29T10:00:00Z",
    "stopped_at": null
  }
}
```

**Behavior:**
- If dry_run=true: Check session exists, return preview info
- If dry_run=false: Execute `oc delete agenticsession <session> -n <project>`
- Return success/failure with descriptive message

---

## Priority 1 Tools (Important)

### acp_restart_session

Restart a stopped session.

**Input Schema:**
```json
{
  "project": "string (required)",
  "session": "string (required)",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "status": "restarting",
  "message": "Successfully restarted session 'foo' in project 'bar'"
}
```

**Behavior:**
- Get current session status
- If dry_run: Return current status and preview
- If not dry_run: Patch session with `{"spec": {"stopped": false}}`
- Command: `oc patch agenticsession <session> -n <project> --type=merge -p '<json>'`

---

### acp_bulk_delete_sessions

Delete multiple sessions in one operation.

**Input Schema:**
```json
{
  "project": "string (required)",
  "sessions": "array[string] (required)",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "deleted": ["session-1", "session-2"],
  "failed": [
    {"session": "session-3", "error": "not found"}
  ],
  "dry_run": false
}
```

**Dry-Run Output:**
```json
{
  "deleted": [],
  "failed": [],
  "dry_run": true,
  "dry_run_info": {
    "would_execute": [
      {"session": "session-1", "info": {...}},
      {"session": "session-2", "info": {...}}
    ],
    "skipped": [
      {"session": "session-3", "reason": "Session 'session-3' not found"}
    ]
  }
}
```

**Behavior:**
- Use `_bulk_operation()` helper
- Call `delete_session()` for each session
- Collect successes and failures
- Return aggregated results

---

### acp_bulk_stop_sessions

Stop multiple running sessions.

**Input Schema:**
```json
{
  "project": "string (required)",
  "sessions": "array[string] (required)",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:** Same structure as bulk_delete

**Behavior:**
- Use `_bulk_operation()` helper
- For each session: Patch with `{"spec": {"stopped": true}}`
- In dry-run: Check status, only count as "would_execute" if status is "running"

---

### acp_get_session_logs

Retrieve container logs for a session.

**Input Schema:**
```json
{
  "project": "string (required)",
  "session": "string (required)",
  "container": "string (optional)",
  "tail_lines": "integer (optional, max: 10000)"
}
```

**Output:**
```json
{
  "logs": "log line 1\nlog line 2\n...",
  "container": "default",
  "lines": 150
}
```

**Behavior:**
- Find pod with label selector: `agenticsession=<session>`
- Get pod name from first matching pod
- Execute: `oc logs <pod> -n <project> [-c <container>] [--tail <lines>]`
- Default tail: 1000 lines (if not specified)
- Max tail: 10,000 lines (security limit)

---

### acp_list_clusters

List configured cluster aliases.

**Input Schema:**
```json
{}
```

**Output:**
```json
{
  "clusters": [
    {
      "name": "dev",
      "server": "https://api.dev.example.com:6443",
      "description": "Development cluster",
      "default_project": "my-workspace",
      "is_default": true
    }
  ],
  "default_cluster": "dev"
}
```

**Behavior:**
- Read from config file
- Mark default cluster with is_default: true
- Synchronous operation (no oc command)

---

### acp_whoami

Get current user and cluster information.

**Input Schema:**
```json
{}
```

**Output:**
```json
{
  "user": "john.doe",
  "cluster": "dev",
  "server": "https://api.dev.example.com:6443",
  "project": "my-workspace",
  "token_expires": null,
  "token_valid": true,
  "authenticated": true
}
```

**Behavior:**
- Execute: `oc whoami` → get user
- Execute: `oc whoami --show-server` → get server URL
- Execute: `oc project -q` → get current project
- Execute: `oc whoami -t` → verify token validity
- Match server URL against config to find cluster name
- Return aggregated info

---

## Priority 2 Tools (Power Users)

### acp_clone_session

Clone an existing session with its configuration.

**Input Schema:**
```json
{
  "project": "string (required)",
  "source_session": "string (required)",
  "new_display_name": "string (required)",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "cloned": true,
  "session": "session-1-clone-abc123",
  "message": "Successfully cloned session 'session-1' to 'session-1-clone-abc123'"
}
```

**Behavior:**
- Get source session spec: `oc get agenticsession <source> -n <project> -o json`
- Copy spec, update displayName, set stopped: false
- Create manifest with generateName: `<source>-clone-`
- Write manifest to secure temp file (0600 permissions, random prefix)
- Execute: `oc create -f <manifest> -o json`
- Parse created session name from response
- Clean up temp file in finally block

---

### acp_get_session_transcript

Retrieve conversation history in JSON or Markdown format.

**Input Schema:**
```json
{
  "project": "string (required)",
  "session": "string (required)",
  "format": "string (optional, default: 'json') - json|markdown"
}
```

**Output (JSON format):**
```json
{
  "transcript": [
    {"role": "user", "content": "...", "timestamp": "..."},
    {"role": "assistant", "content": "...", "timestamp": "..."}
  ],
  "format": "json",
  "message_count": 2
}
```

**Output (Markdown format):**
```json
{
  "transcript": "# Session Transcript: session-1\n\n## Message 1 - user\n...",
  "format": "markdown",
  "message_count": 2
}
```

**Behavior:**
- Get session: `oc get agenticsession <session> -n <project> -o json`
- Extract: `status.transcript` (array of message objects)
- If format=markdown: Convert to markdown with headers, timestamps
- If format=json: Return raw array

---

### acp_update_session

Update session metadata (display name, timeout).

**Input Schema:**
```json
{
  "project": "string (required)",
  "session": "string (required)",
  "display_name": "string (optional)",
  "timeout": "integer (optional) - seconds",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "updated": true,
  "session": {...},
  "message": "Successfully updated session 'foo'"
}
```

**Behavior:**
- Get current session
- If dry_run: Show current values and what would change
- Build patch: `{"spec": {"displayName": "...", "timeout": 3600}}`
- Execute: `oc patch agenticsession <session> -n <project> --type=merge -p '<json>' -o json`
- Return updated session data

---

### acp_export_session

Export session configuration and transcript for archival.

**Input Schema:**
```json
{
  "project": "string (required)",
  "session": "string (required)"
}
```

**Output:**
```json
{
  "exported": true,
  "data": {
    "config": {
      "name": "session-1",
      "displayName": "My Session",
      "repos": ["https://github.com/..."],
      "workflow": "bugfix",
      "llmConfig": {"model": "claude-sonnet-4", "temperature": 0.3}
    },
    "transcript": [...],
    "metadata": {
      "created": "2026-01-29T10:00:00Z",
      "status": "stopped",
      "stoppedAt": "2026-01-29T11:00:00Z",
      "messageCount": 42
    }
  },
  "message": "Successfully exported session 'session-1'"
}
```

**Behavior:**
- Get session data
- Get transcript via `get_session_transcript()`
- Combine into export structure
- Return complete export

---

## Priority 3 Tools (Advanced)

### acp_get_session_metrics

Get usage statistics (tokens, duration, tool calls).

**Input Schema:**
```json
{
  "project": "string (required)",
  "session": "string (required)"
}
```

**Output:**
```json
{
  "token_count": 15420,
  "duration_seconds": 3600,
  "tool_calls": {
    "Read": 42,
    "Write": 15,
    "Bash": 8
  },
  "message_count": 84,
  "status": "stopped"
}
```

**Behavior:**
- Get session and transcript
- Calculate approximate token count: `sum(len(msg.content.split()) * 1.3)`
- Extract tool calls from transcript
- Calculate duration: `stopped_at - created_at`
- Return aggregated metrics

---

### acp_list_workflows

Discover available workflows from a Git repository.

**Input Schema:**
```json
{
  "repo_url": "string (optional, default: 'https://github.com/ambient-code/ootb-ambient-workflows')"
}
```

**Output:**
```json
{
  "workflows": [
    {
      "name": "bugfix",
      "path": "bugfix.yaml",
      "description": "Fix bugs and issues"
    }
  ],
  "repo_url": "https://github.com/...",
  "count": 1
}
```

**Behavior:**
- Validate URL (must be https:// or http://, no special characters)
- Create secure temp directory with random prefix
- Execute: `git clone --depth 1 -- <url> <temp_dir>` with 60s timeout
- Find all `workflows/**/*.yaml` files (max 100)
- Validate files are within workflows directory (prevent traversal)
- Parse each YAML to extract description
- Clean up temp directory in finally block

---

### acp_create_session_from_template

Create session from predefined template.

**Input Schema:**
```json
{
  "project": "string (required)",
  "template": "string (required) - triage|bugfix|feature|exploration",
  "display_name": "string (required)",
  "repos": "array[string] (optional)",
  "dry_run": "boolean (optional, default: false)"
}
```

**Templates:**
```json
{
  "triage": {
    "workflow": "triage",
    "llmConfig": {"model": "claude-sonnet-4", "temperature": 0.7},
    "description": "Triage and analyze issues"
  },
  "bugfix": {
    "workflow": "bugfix",
    "llmConfig": {"model": "claude-sonnet-4", "temperature": 0.3},
    "description": "Fix bugs and issues"
  },
  "feature": {
    "workflow": "feature-development",
    "llmConfig": {"model": "claude-sonnet-4", "temperature": 0.5},
    "description": "Develop new features"
  },
  "exploration": {
    "workflow": "codebase-exploration",
    "llmConfig": {"model": "claude-sonnet-4", "temperature": 0.8},
    "description": "Explore codebase"
  }
}
```

**Output:**
```json
{
  "created": true,
  "session": "bugfix-abc123",
  "message": "Successfully created session 'bugfix-abc123' from template 'bugfix'"
}
```

**Behavior:**
- Validate template exists
- If dry_run: Show template config
- Create manifest with template's workflow and llmConfig
- Write to secure temp file
- Execute: `oc create -f <manifest> -o json`
- Clean up temp file

---

## Authentication Tools

### acp_login

Authenticate to OpenShift cluster.

**Input Schema:**
```json
{
  "cluster": "string (required) - alias or server URL",
  "web": "boolean (optional, default: true)",
  "token": "string (optional)"
}
```

**Output:**
```json
{
  "authenticated": true,
  "user": "john.doe",
  "cluster": "dev",
  "server": "https://api.dev.example.com:6443",
  "message": "Successfully logged in to dev"
}
```

**Behavior:**
- Resolve cluster name to server URL from config
- If token provided: `oc login --token <token> --server <server>`
- If web=true: `oc login --web --server <server>` (opens browser)
- After login: Call `whoami()` to get user info
- Return login status

---

### acp_switch_cluster

Switch to a different cluster context.

**Input Schema:**
```json
{
  "cluster": "string (required) - cluster alias"
}
```

**Output:**
```json
{
  "switched": true,
  "previous": "dev",
  "current": "prod",
  "user": "john.doe",
  "message": "Switched from dev to prod"
}
```

**Behavior:**
- Verify cluster exists in config
- Get current cluster via `whoami()`
- Execute: `oc login --server <server>` (assumes already authenticated)
- Get new user info via `whoami()`
- Return switch status

---

### acp_add_cluster

Add cluster to configuration file.

**Input Schema:**
```json
{
  "name": "string (required)",
  "server": "string (required) - https://...",
  "description": "string (optional)",
  "default_project": "string (optional)",
  "set_default": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "added": true,
  "cluster": {
    "name": "prod",
    "server": "https://api.prod.example.com:6443",
    "description": "Production cluster",
    "default_project": "my-workspace",
    "is_default": false
  },
  "message": "Successfully added cluster 'prod'"
}
```

**Behavior:**
- Validate inputs (name format, server URL)
- Add to config dict
- Write config to YAML file
- Set file permissions to 0600
- Return success status

---

## Security Requirements Summary

### Input Validation

**Resource Name Validation Pattern:** `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`
- Max Length: 253 characters
- Applies to: project, session, container, cluster names, default_project

**URL Validation:**
- Must start with `https://` or `http://`
- No special characters: `;`, `|`, `&`, `$`, `` ` ``, `\n`, `\r`, space

**Label Selector Validation Pattern:** `^[a-zA-Z0-9=,_-]+$`

### Command Injection Prevention

- Always use argument arrays (never shell=True)
- Validate all arguments before execution
- Use `--` separator for git commands

### Resource Exhaustion Protection

- Default timeout: 300 seconds (5 minutes)
- Git clone timeout: 60 seconds
- Max log lines: 10,000 per request
- Default log lines: 1,000 (if not specified)
- Max workflow files: 100 per repository

### File System Security

- Temporary files must use secure creation with 0600 permissions
- Configuration files must be within user's home directory
- Configuration files must have 0600 permissions
- Path traversal prevention using `Path.resolve()`

### Resource Type Whitelist

Only allow these Kubernetes resource types:
- `agenticsession`
- `pods`
- `event`

---

## Error Handling

### Exception Types

**ValueError:**
- Input validation failures
- Configuration errors
- Invalid parameters
- Log as WARNING

**asyncio.TimeoutError:**
- Command timeouts
- Process exceeded time limit
- Log as ERROR

**Exception:**
- Unexpected errors
- System failures
- Log as ERROR with full stack trace

### Error Response Format

**From Client Methods:**
```json
{
  "success": false,
  "error": "Detailed error message",
  "message": "User-friendly error message"
}
```

**Generic Error Responses:**
```
Validation Error: Field 'session' contains invalid characters
Timeout Error: Command timed out after 300s
Error: Unexpected system error
```

---

## Configuration Management

**Config File Location:** `~/.config/acp/clusters.yaml`

**Format:**
```yaml
clusters:
  dev:
    server: https://api.dev.example.com:6443
    description: Development cluster
    default_project: my-workspace

  prod:
    server: https://api.prod.example.com:6443
    description: Production cluster
    default_project: prod-workspace

default_cluster: dev
```

**Permissions:** 0600 (read/write owner only)

**Environment Variable Override:** `ACP_CLUSTER_CONFIG`

---

## Tool Inventory Summary

**Total: 19 Tools**

| Priority | Category | Count | Tools |
|----------|----------|-------|-------|
| P0 | Critical | 2 | list_sessions, delete_session |
| P1 | Important | 6 | restart, bulk_delete, bulk_stop, logs, clusters, whoami |
| P2 | Power Users | 4 | clone, transcript, update, export |
| P3 | Advanced | 3 | metrics, workflows, templates |
| Auth | Authentication | 4 | login, switch_cluster, add_cluster, enhanced whoami |

---

## Implementation Notes

### Subprocess Execution

All subprocess operations must:
1. Use `asyncio.create_subprocess_exec()` (not shell=True)
2. Have timeouts enforced with `asyncio.wait_for()`
3. Kill processes on timeout
4. Capture stdout/stderr

### Temporary Files

Create with secure parameters:
```python
fd, filepath = tempfile.mkstemp(
    suffix='.yaml',
    prefix=f'acp-operation-{secrets.token_hex(8)}-'
)
```

Always clean up in finally block with try/except.

### Filtering and Sorting

- Build filter predicates as callables
- Use single-pass filtering: `all(f(s) for f in filters)`
- Sort results only if `sort_by` specified
- Apply limit after filtering and sorting

### MCP Protocol

- Transport: stdio
- Protocol Version: MCP 1.0.0+
- All responses: wrapped in TextContent with type="text"
- Tool definitions include inputSchema with JSON Schema

---

End of API Reference
