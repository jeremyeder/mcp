# Changelog

All notable changes to this project will be documented in this file.

---

## [0.1.0] - 2026-01-30

### Changed

**Improved Error Message Formatting**

Error messages now distinguish between expected states and actual errors:

**Before**:
```
Error: No pods found for session-1769698517
Error: No transcript data available
```

**After**:
```
No logs available: No pods found for session-1769698517

Note: This is expected for stopped sessions or sessions without active pods.
```

**Files modified**: `src/mcp_acp/formatters.py`

**Impact**: Clearer, less alarming output for normal operational states (stopped sessions, new sessions, sessions without data).

### Added

**P0 Priority Features**
- `acp_delete_session`: Delete sessions with dry-run support
- `acp_list_sessions`: Enhanced filtering by status, age, display name
- Session sorting by created, stopped, or name
- Time-based filtering (7d, 24h, 30m)
- Result limiting for large session lists

**P1 Priority Features**
- `acp_restart_session`: Restart stopped sessions
- `acp_bulk_delete_sessions`: Delete multiple sessions
- `acp_bulk_stop_sessions`: Stop multiple running sessions
- `acp_get_session_logs`: Retrieve container logs
- `acp_list_clusters`: List configured cluster aliases
- `acp_whoami`: Get authentication status

**Core Features**
- Dry-run mode for all mutating operations
- Cluster configuration via `~/.config/acp/clusters.yaml`
- OpenShift CLI integration
- Auto-fill default project from config
- Project parameter made optional (uses default_project)
- MCP server with stdio transport

**Developer Features**
- Comprehensive test suite (pytest)
- Type hints throughout
- Black formatting, Ruff linting, MyPy checking
- CI/CD ready

### Fixed

- Entry point async function error (changed to `run()`)
- Dict hashing error in schema creation (added `.copy()`)
- NoneType errors when sessions lack transcript data (added `or []` fallback)
- Default project not being used (improved auto-fill logic)
- Project parameter still required even with default set (made optional in schemas)
- `whoami` showing wrong project (now uses config default_project)

### Documentation

- Complete installation guide (INSTALL.md)
- Comprehensive troubleshooting (TROUBLESHOOTING.md)
- Trigger phrases reference (TRIGGER_PHRASES.md)
- Usage examples (USAGE_GUIDE.md)
- API reference (API_REFERENCE.md)
- Security documentation (SECURITY.md)
- Quick start guide (QUICKSTART.md)

---

## [Unreleased]

### Planned - P2 Features
- `acp_clone_session`: Duplicate session configurations
- `acp_get_session_transcript`: Retrieve conversation history
- `acp_update_session`: Modify session metadata
- `acp_export_session`: Export session data

### Planned - P3 Features
- `acp_get_session_metrics`: Token usage and statistics
- `acp_list_workflows`: Discover available workflows
- `acp_create_session_from_template`: Predefined configs
- `acp_watch_events`: Real-time event streaming

### Planned - Auth Enhancements
- `acp_login`: Web-based authentication flow
- `acp_switch_cluster`: Switch between clusters
- `acp_add_cluster`: Register new cluster aliases
- Token expiry detection and warnings

---

## Release Notes

### v0.1.0 (2026-01-30)

Initial release implementing P0 and P1 priority features with improved error handling.

**Highlights**:
- Session management tools with dry-run support
- Smart error messages (distinguishes expected states from errors)
- Auto-fill default project from config
- Comprehensive filtering and bulk operations
- Full test coverage

**Breaking Changes**: None (initial release)

**Known Issues**:
- Web-based authentication not yet implemented
- Cluster switching requires manual `oc login`
- Token expiry detection not available

**Upgrade Notes**: First release, no upgrade needed

**SHA256**: `16a1a8efe682051bddc70592f94ed996f1f34067d37edcd33c50e3c32b999d27`
