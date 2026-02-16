# ACP MCP Server - API Reference

Complete reference for all 8 tools available in the ACP MCP Server.

See [issue #27](https://github.com/ambient-code/mcp/issues/27) for planned additional tools.

---

## Table of Contents

1. [Session Management](#session-management)
   - [acp_list_sessions](#acp_list_sessions)
   - [acp_get_session](#acp_get_session)
   - [acp_create_session](#acp_create_session)
   - [acp_delete_session](#acp_delete_session)

2. [Bulk Operations](#bulk-operations)
   - [acp_bulk_delete_sessions](#acp_bulk_delete_sessions)

3. [Cluster Management](#cluster-management)
   - [acp_list_clusters](#acp_list_clusters)
   - [acp_whoami](#acp_whoami)
   - [acp_switch_cluster](#acp_switch_cluster)

---

## Session Management

### acp_list_sessions

List sessions with advanced filtering, sorting, and limiting.

**Input Schema:**
```json
{
  "project": "string (optional, uses default if not provided)",
  "status": "string (optional) - running|stopped|creating|failed",
  "older_than": "string (optional) - e.g., '7d', '24h', '30m'",
  "sort_by": "string (optional) - created|stopped|name",
  "limit": "integer (optional, minimum: 1)"
}
```

**Output:**
```json
{
  "sessions": [
    {
      "id": "session-1",
      "status": "running",
      "createdAt": "2026-01-29T10:00:00Z"
    }
  ],
  "total": 10,
  "filters_applied": {"status": "running", "limit": 10}
}
```

**Behavior:**
- Calls `GET /v1/sessions` on the public-api gateway
- Builds filter predicates based on parameters
- Single-pass filtering: `all(f(s) for f in filters)`
- Sorts results if `sort_by` specified (reverse for created/stopped, normal for name)
- Applies limit after filtering and sorting

---

### acp_get_session

Get details of a specific session by ID.

**Input Schema:**
```json
{
  "project": "string (optional, uses default if not provided)",
  "session": "string (required) - Session ID"
}
```

**Output:**
```json
{
  "id": "session-1",
  "status": "running",
  "displayName": "My Session",
  "createdAt": "2026-01-29T10:00:00Z"
}
```

**Behavior:**
- Calls `GET /v1/sessions/{session}` on the public-api gateway
- Validates session name (DNS-1123 format)

---

### acp_create_session

Create an ACP AgenticSession with a custom prompt.

**Input Schema:**
```json
{
  "project": "string (optional, uses default if not provided)",
  "initial_prompt": "string (required) - The prompt/instructions for the session",
  "display_name": "string (optional) - Human-readable display name",
  "repos": "array[string] (optional) - Repository URLs to clone",
  "interactive": "boolean (optional, default: false)",
  "model": "string (optional, default: 'claude-sonnet-4')",
  "timeout": "integer (optional, default: 900, minimum: 60) - seconds",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "created": true,
  "session": "compiled-abc12",
  "project": "my-workspace",
  "message": "Session 'compiled-abc12' created in project 'my-workspace'"
}
```

**Dry-Run Output:**
```json
{
  "dry_run": true,
  "success": true,
  "message": "Would create session with custom prompt",
  "manifest": {
    "initialPrompt": "...",
    "interactive": false,
    "llmConfig": {"model": "claude-sonnet-4"},
    "timeout": 900
  },
  "project": "my-workspace"
}
```

**Behavior:**
- Validates project name (DNS-1123 format)
- If dry_run: Returns the manifest without calling the API
- Calls `POST /v1/sessions` on the public-api gateway

---

### acp_delete_session

Delete a session with optional dry-run.

**Input Schema:**
```json
{
  "project": "string (optional, uses default if not provided)",
  "session": "string (required)",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "deleted": true,
  "message": "Successfully deleted session 'foo' from project 'bar'"
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
    "created": "2026-01-29T10:00:00Z"
  }
}
```

**Behavior:**
- If dry_run: Calls `GET /v1/sessions/{session}` to verify existence
- If not dry_run: Calls `DELETE /v1/sessions/{session}`

---

## Bulk Operations

### acp_bulk_delete_sessions

Delete multiple sessions (max 3). Requires `confirm=true` for non-dry-run execution.

**Input Schema:**
```json
{
  "project": "string (optional, uses default if not provided)",
  "sessions": "array[string] (required) - max 3 items",
  "confirm": "boolean (optional, default: false) - required for destructive operations",
  "dry_run": "boolean (optional, default: false)"
}
```

**Output:**
```json
{
  "deleted": ["session-1", "session-2"],
  "failed": [
    {"session": "session-3", "error": "not found"}
  ]
}
```

**Behavior:**
- Validates bulk limit (max 3 sessions)
- Server enforces `confirm=true` for non-dry-run execution
- Iterates through sessions, calling `delete_session()` for each

---

## Cluster Management

### acp_list_clusters

List configured cluster aliases from clusters.yaml.

**Input Schema:**
```json
{}
```

**Output:**
```json
{
  "clusters": [
    {
      "name": "vteam-stage",
      "server": "https://public-api-ambient.apps.vteam-stage.example.com",
      "description": "Staging cluster",
      "default_project": "my-workspace",
      "is_default": true
    }
  ],
  "default_cluster": "vteam-stage"
}
```

**Behavior:**
- Reads from clusters.yaml configuration
- Marks default cluster with `is_default: true`
- Synchronous operation (no API call)

---

### acp_whoami

Get current configuration and authentication status.

**Input Schema:**
```json
{}
```

**Output:**
```json
{
  "cluster": "vteam-stage",
  "server": "https://public-api-ambient.apps.vteam-stage.example.com",
  "project": "my-workspace",
  "token_valid": true,
  "authenticated": true
}
```

**Behavior:**
- Reads current cluster configuration
- Checks if Bearer token is configured
- Returns cluster, server, project, and authentication status

---

### acp_switch_cluster

Switch to a different cluster context.

**Input Schema:**
```json
{
  "cluster": "string (required) - cluster alias name"
}
```

**Output:**
```json
{
  "switched": true,
  "previous": "vteam-stage",
  "current": "vteam-prod",
  "message": "Switched from vteam-stage to vteam-prod"
}
```

**Behavior:**
- Verifies cluster exists in configuration
- Updates the active cluster context

---

## Error Handling

**Validation errors:**
```
Validation Error: Field 'session' contains invalid characters
```

**Timeout errors:**
```
Timeout Error: Request timed out: /v1/sessions
```

**API errors:**
```
Error: HTTP 404: session not found
```

---

## Configuration

**Config File Location:** `~/.config/acp/clusters.yaml`

**Format:**
```yaml
clusters:
  vteam-stage:
    server: https://public-api-ambient.apps.vteam-stage.example.com
    token: your-bearer-token-here
    description: Staging cluster
    default_project: my-workspace

default_cluster: vteam-stage
```

**Environment Variables:**
- `ACP_CLUSTER_CONFIG`: Override config file path
- `ACP_TOKEN`: Override Bearer token

---

## Tool Inventory Summary

**Total: 8 Tools**

| Category | Count | Tools |
|----------|-------|-------|
| Session Management | 4 | list_sessions, get_session, create_session, delete_session |
| Bulk Operations | 1 | bulk_delete_sessions |
| Cluster Management | 3 | list_clusters, whoami, switch_cluster |

See [issue #27](https://github.com/ambient-code/mcp/issues/27) for 21 planned additional tools.

---

## MCP Protocol

- Transport: stdio
- Protocol Version: MCP 1.0.0+
- All responses: wrapped in TextContent with type="text"
- Tool definitions include inputSchema with JSON Schema

---

End of API Reference
