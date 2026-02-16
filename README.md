# MCP ACP Server

A Model Context Protocol (MCP) server for managing Ambient Code Platform (ACP) sessions via the public-api gateway.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Tool Reference](#tool-reference)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)
- [Security](#security)
- [Development](#development)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Status](#status)

---

## Quick Start

```bash
# Install
git clone https://github.com/ambient-code/mcp
pip install dist/mcp_acp-*.whl

# Configure
mkdir -p ~/.config/acp
cat > ~/.config/acp/clusters.yaml <<EOF
clusters:
  my-cluster:
    server: https://public-api-ambient.apps.your-cluster.example.com
    token: your-bearer-token-here
    default_project: my-workspace
default_cluster: my-cluster
EOF
chmod 600 ~/.config/acp/clusters.yaml
```

Then add to your MCP client ([Claude Desktop](#claude-desktop), [Claude Code](#claude-code-cli), or [uvx](#using-uvx)) and try:

```
List my ACP sessions
```

---

## Features

| Tool | Description |
|------|-------------|
| `acp_list_sessions` | List/filter sessions by status, age, with sorting and limits |
| `acp_get_session` | Get detailed session information by ID |
| `acp_create_session` | Create sessions with custom prompts, repos, model selection, and timeout |
| `acp_delete_session` | Delete sessions with dry-run preview |
| `acp_bulk_delete_sessions` | Delete multiple sessions (max 3) with confirmation and dry-run |
| `acp_list_clusters` | List configured cluster aliases |
| `acp_whoami` | Check current configuration and authentication status |
| `acp_switch_cluster` | Switch between configured clusters |

**Safety Features:**

- **Dry-Run Mode** — All mutating operations support `dry_run` for safe preview before executing
- **Bulk Operation Limits** — Maximum 3 items per bulk operation with confirmation requirement

---

## Installation

### From Wheel

```bash
pip install dist/mcp_acp-*.whl
```

### From Source

```bash
git clone https://github.com/ambient-code/mcp
cd mcp
uv pip install -e ".[dev]"
```

**Requirements:**

- Python 3.10+
- Bearer token for the ACP public-api gateway
- Access to an ACP cluster

---

## Configuration

### Cluster Config

Create `~/.config/acp/clusters.yaml`:

```yaml
clusters:
  vteam-stage:
    server: https://public-api-ambient.apps.vteam-stage.example.com
    token: your-bearer-token-here
    description: "V-Team Staging Environment"
    default_project: my-workspace

  vteam-prod:
    server: https://public-api-ambient.apps.vteam-prod.example.com
    token: your-bearer-token-here
    description: "V-Team Production"
    default_project: my-workspace

default_cluster: vteam-stage
```

Then secure the file:

```bash
chmod 600 ~/.config/acp/clusters.yaml
```

### Authentication

Add your Bearer token to each cluster entry under the `token` field, or set the `ACP_TOKEN` environment variable:

```bash
export ACP_TOKEN=your-bearer-token-here
```

Get your token from the ACP platform administrator or the gateway's authentication endpoint.

### Claude Desktop

Edit your configuration file:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**: `~/.config/claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "acp": {
      "command": "mcp-acp",
      "args": [],
      "env": {
        "ACP_CLUSTER_CONFIG": "${HOME}/.config/acp/clusters.yaml"
      }
    }
  }
}
```

After editing, **completely quit and restart Claude Desktop** (not just close the window).

### Claude Code (CLI)

```bash
claude mcp add mcp-acp -t stdio mcp-acp
```

### Using uvx

[uvx](https://docs.astral.sh/uv/) provides zero-install execution — no global Python pollution, auto-caching, and fast startup.

```bash
# Install uv (if needed)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Claude Desktop config for uvx:

```json
{
  "mcpServers": {
    "acp": {
      "command": "uvx",
      "args": ["mcp-acp"]
    }
  }
}
```

For a local wheel (before PyPI publish):

```json
{
  "mcpServers": {
    "acp": {
      "command": "uvx",
      "args": ["--from", "/full/path/to/dist/mcp_acp-0.1.0-py3-none-any.whl", "mcp-acp"]
    }
  }
}
```

---

## Usage

### Examples

```
# List sessions
List my ACP sessions
Show running sessions in my-workspace
List sessions older than 7 days in my-workspace
List sessions sorted by creation date, limit 20

# Session details
Get details for ACP session session-name
Show AgenticSession session-name in my-workspace

# Create a session
Create a new ACP session with prompt "Run all unit tests and report results"

# Delete with dry-run (safe!)
Delete test-session from my-workspace in dry-run mode

# Actually delete
Delete test-session from my-workspace

# Bulk delete (dry-run first)
Delete these sessions: session-1, session-2, session-3 from my-workspace (dry-run first)

# Cluster operations
Check my ACP authentication
List my ACP clusters
Switch to ACP cluster vteam-prod
```

### Trigger Keywords

Include one of these keywords so your MCP client routes the request to ACP: **ACP**, **ambient**, **AgenticSession**, or use tool names directly (e.g., `acp_list_sessions`, `acp_whoami`). Without a keyword, generic phrases like "list sessions" may not trigger the server.

### Quick Reference

| Task | Command Pattern |
|------|----------------|
| Check auth | `Use acp_whoami` |
| List all | `List ACP sessions in PROJECT` |
| Filter status | `List running sessions in PROJECT` |
| Filter age | `List sessions older than 7d in PROJECT` |
| Get details | `Get details for ACP session SESSION` |
| Create | `Create ACP session with prompt "..."` |
| Delete (dry) | `Delete SESSION in PROJECT (dry-run)` |
| Delete (real) | `Delete SESSION in PROJECT` |
| Bulk delete | `Delete session-1, session-2 in PROJECT` |
| List clusters | `Use acp_list_clusters` |

---

## Tool Reference

For complete API specifications including input schemas, output formats, and behavior details, see [API_REFERENCE.md](API_REFERENCE.md).

| Category | Tool | Description |
|----------|------|-------------|
| **Session** | `acp_list_sessions` | List/filter sessions |
| | `acp_get_session` | Get session details |
| | `acp_create_session` | Create session with prompt |
| | `acp_delete_session` | Delete with dry-run support |
| **Bulk** | `acp_bulk_delete_sessions` | Delete multiple sessions (max 3) |
| **Cluster** | `acp_list_clusters` | List configured clusters |
| | `acp_whoami` | Check authentication status |
| | `acp_switch_cluster` | Switch cluster context |

---

## Troubleshooting

### "No authentication token available"

Your token is not configured. Either:

1. Add `token: your-token-here` to your cluster in `~/.config/acp/clusters.yaml`
2. Set the `ACP_TOKEN` environment variable

### "HTTP 401: Unauthorized"

Your token is expired or invalid. Get a new token from the ACP platform administrator.

### "HTTP 403: Forbidden"

You don't have permission for this operation. Contact your ACP platform administrator.

### "Direct Kubernetes API URLs (port 6443) are not supported"

You're using a direct K8s API URL. Use the public-api gateway URL instead:

- **Wrong**: `https://api.cluster.example.com:6443`
- **Correct**: `https://public-api-ambient.apps.cluster.example.com`

### "mcp-acp: command not found"

Add Python user bin to PATH:

- **macOS**: `export PATH="$HOME/Library/Python/3.*/bin:$PATH"`
- **Linux**: `export PATH="$HOME/.local/bin:$PATH"`

Then restart your shell.

### MCP Tools Not Showing in Claude

1. Check Claude Desktop logs: Help → View Logs
2. Verify config file syntax is valid JSON
3. Make sure `mcp-acp` is in PATH
4. Restart Claude Desktop completely (quit, not just close)

### "Permission denied" on clusters.yaml

```bash
chmod 600 ~/.config/acp/clusters.yaml
chmod 700 ~/.config/acp
```

---

## Architecture

- **MCP SDK** — Standard MCP protocol implementation (stdio transport)
- **httpx** — Async HTTP REST client for the public-api gateway
- **Pydantic** — Settings management and input validation
- **Three-layer design** — Server (tool dispatch) → Client (HTTP + validation) → Formatters (output)

See [CLAUDE.md](CLAUDE.md#architecture-overview) for complete system design.

---

## Security

- **Input Validation** — DNS-1123 format validation for all resource names
- **Gateway URL Enforcement** — Direct K8s API URLs (port 6443) rejected
- **Bearer Token Security** — Tokens filtered from logs, sourced from config or environment
- **Resource Limits** — Bulk operations limited to 3 items with confirmation

See [SECURITY.md](SECURITY.md) for complete security documentation including threat model and best practices.

---

## Development

```bash
# One-time setup
uv venv && uv pip install -e ".[dev]"

# Pre-commit workflow
uv run ruff format . && uv run ruff check . && uv run pytest tests/

# Run with coverage
uv run pytest tests/ --cov=src/mcp_acp --cov-report=html

# Build wheel
uvx --from build pyproject-build --installer uv
```

See [CLAUDE.md](CLAUDE.md#development-commands) for contributing guidelines.

---

## Roadmap

Current implementation provides 8 core tools. See [issue #27](https://github.com/ambient-code/mcp/issues/27) for 21 planned additional tools covering:

- Session lifecycle (restart, clone, templates, update, export)
- Observability (logs, transcripts, metrics)
- Label management and advanced bulk operations
- Cluster and workflow management

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass (`uv run pytest tests/`)
5. Ensure code quality checks pass (`uv run ruff format . && uv run ruff check .`)
6. Submit a pull request

---

## Status

**Code**: Production-Ready |
**Tests**: All Passing |
**Security**: Input validation, gateway enforcement, token security |
**Tools**: 8 implemented ([21 more planned](https://github.com/ambient-code/mcp/issues/27))

---

## Documentation

- **[API_REFERENCE.md](API_REFERENCE.md)** — Full API specifications for all 8 tools
- **[SECURITY.md](SECURITY.md)** — Security features, threat model, and best practices
- **[CLAUDE.md](CLAUDE.md)** — System architecture and development guide

## License

MIT License — See LICENSE file for details.

## Support

For issues and feature requests, use the [GitHub issue tracker](https://github.com/ambient-code/mcp/issues).
