# Migrating to Structured Logging (structlog)

This guide shows how to migrate remaining logging calls to structlog.

---

## Quick Reference

### Before (old logging)
```python
import logging
logger = logging.getLogger(__name__)

logger.info(f"Tool call started: {name} with arguments: {safe_args}")
logger.warning(f"Unknown tool requested: {name}")
logger.error(f"Failed to initialize: {e}")
```

### After (structured logging)
```python
from utils.pylogger import get_python_logger
logger = get_python_logger()

logger.info("tool_call_started", tool=name, arguments=safe_args)
logger.warning("unknown_tool_requested", tool=name)
logger.error("initialization_failed", error=str(e))
```

---

## Benefits of Structured Logging

1. **Machine Parseable**: JSON output easy to parse/search
2. **Consistent Fields**: Automatic timestamp, log level, logger name
3. **Better Searching**: `grep '"tool":"acp_delete_session"'` vs parsing strings
4. **Metrics/Alerts**: Easy to aggregate and alert on specific events

---

## Migration Patterns

### Pattern 1: Simple Messages

**Before**:
```python
logger.info("ACP client initialized successfully")
```

**After**:
```python
logger.info("acp_client_initialized")
```

### Pattern 2: Messages with Variables

**Before**:
```python
logger.info(f"Tool call started: {name} with arguments: {safe_args}")
```

**After**:
```python
logger.info("tool_call_started", tool=name, arguments=safe_args)
```

### Pattern 3: Error Messages

**Before**:
```python
logger.error(f"Failed to initialize ACP client: {e}")
```

**After**:
```python
logger.error("acp_client_init_failed", error=str(e))
```

### Pattern 4: Warning with Context

**Before**:
```python
logger.warning(f"Tool {name} returned error: {result.get('error')}")
```

**After**:
```python
logger.warning("tool_returned_error", tool=name, error=result.get('error'))
```

### Pattern 5: Debug with Multiple Fields

**Before**:
```python
logger.debug(f"Processing session {session} in project {project}")
```

**After**:
```python
logger.debug("processing_session", session=session, project=project)
```

---

## Remaining Migrations in server.py

### Lines to Update

**Line 117**:
```python
# Before
logger.info(f"Initializing ACP client with config: {config_path or 'default'}")

# After
logger.info("acp_client_initializing", config_path=config_path or "default")
```

**Line 119**:
```python
# Before
logger.info("ACP client initialized successfully")

# After
logger.info("acp_client_initialized")
```

**Line 121**:
```python
# Before
logger.error(f"Failed to initialize ACP client: {e}")

# After
logger.error("acp_client_init_failed", error=str(e))
```

**Line 124**:
```python
# Before
logger.error(f"Unexpected error initializing ACP client: {e}", exc_info=True)

# After
logger.error("acp_client_init_unexpected_error", error=str(e), exc_info=True)
```

**Line 509**:
```python
# Before
logger.info(f"Tool call started: {name} with arguments: {safe_args}")

# After
logger.info("tool_call_started", tool=name, arguments=safe_args)
```

**Line 518**:
```python
# Before
logger.warning(f"Unknown tool requested: {name}")

# After
logger.warning("unknown_tool_requested", tool=name)
```

**Line 530**:
```python
# Before
logger.info(f"Auto-filled project from config: {default_project}")

# After
logger.info("project_autofilled", project=default_project)
```

**Line 540**:
```python
# Before
logger.info(f"Tool call completed: {name} in {elapsed:.2f}s")

# After
logger.info("tool_call_completed", tool=name, elapsed_seconds=round(elapsed, 2))
```

**Line 545**:
```python
# Before
logger.warning(f"Tool {name} returned error: {result.get('error')}")

# After
logger.warning("tool_returned_error", tool=name, error=result.get('error'))
```

**Line 547**:
```python
# Before
logger.warning(f"Tool {name} failed: {result.get('message')}")

# After
logger.warning("tool_failed", tool=name, message=result.get('message'))
```

**Line 554**:
```python
# Before
logger.warning(f"Validation error in tool {name} after {elapsed:.2f}s: {e}")

# After
logger.warning("tool_validation_error", tool=name, elapsed_seconds=round(elapsed, 2), error=str(e))
```

**Line 558**:
```python
# Before
logger.error(f"Timeout in tool {name} after {elapsed:.2f}s: {e}")

# After
logger.error("tool_timeout", tool=name, elapsed_seconds=round(elapsed, 2), error=str(e))
```

**Line 562**:
```python
# Before
logger.error(f"Unexpected error in tool {name} after {elapsed:.2f}s: {e}", exc_info=True)

# After
logger.error("tool_unexpected_error", tool=name, elapsed_seconds=round(elapsed, 2), error=str(e), exc_info=True)
```

---

## JSON Output Examples

### Before (String Format)
```
INFO:mcp_acp.server:Tool call started: acp_delete_session with arguments: {'project': 'my-workspace', 'session': 'test-1'}
INFO:mcp_acp.server:Tool call completed: acp_delete_session in 1.23s
```

### After (Structured JSON)
```json
{"event":"tool_call_started","tool":"acp_delete_session","arguments":{"project":"my-workspace","session":"test-1"},"timestamp":"2026-01-30T05:45:12.123456Z","level":"info","logger":"mcp_acp.server"}
{"event":"tool_call_completed","tool":"acp_delete_session","elapsed_seconds":1.23,"timestamp":"2026-01-30T05:45:13.345678Z","level":"info","logger":"mcp_acp.server"}
```

### Querying JSON Logs
```bash
# Find all tool timeouts
grep '"event":"tool_timeout"' logs.json

# Find specific tool calls
grep '"tool":"acp_delete_session"' logs.json

# Extract just error events
jq 'select(.level == "error")' logs.json

# Count tool calls by name
jq -r .tool logs.json | sort | uniq -c
```

---

## Event Naming Conventions

Use snake_case with descriptive names:

**Good**:
- `tool_call_started`
- `session_deleted`
- `cluster_config_loaded`
- `authentication_failed`

**Bad**:
- `ToolCallStarted` (PascalCase)
- `Started` (too generic)
- `delete` (verb only, unclear)
- `error` (use as a field, not event name)

---

## Testing Structured Logs

```python
import json
from utils.pylogger import get_python_logger

logger = get_python_logger()

# Log an event
logger.info("test_event", foo="bar", count=42)

# Output will be JSON:
# {"event":"test_event","foo":"bar","count":42,"timestamp":"...","level":"info",...}
```

---

## Gradual Migration Plan

1. ✅ **Add infrastructure** - utils/pylogger.py (DONE)
2. ✅ **Update imports** - server.py, client.py (DONE)
3. ⏭️ **Migrate server.py** - 13 log statements
4. ⏭️ **Migrate client.py** - ~20 log statements
5. ⏭️ **Migrate formatters.py** - ~5 log statements
6. ⏭️ **Test output** - Verify JSON format
7. ⏭️ **Update docs** - Add logging section to README

---

## Automation Script

To migrate all at once, you can use this sed script:

```bash
# Example: Convert simple patterns
sed -i 's/logger\.info(f"Tool call started: {name}/logger.info("tool_call_started", tool=name/g' server.py

# For complex migrations, manual review is recommended
```

Or use a Python script to parse and transform:

```python
import re

def migrate_log_call(line):
    # Pattern: logger.info(f"Message: {var}")
    # Replace with: logger.info("event_name", field=var)
    ...
```

---

## Next Steps

1. Apply the specific migrations listed above to `server.py`
2. Search for all `logger.` calls in `client.py` and migrate
3. Test that JSON output is being produced
4. Commit with message: "Migrate to structured logging (structlog)"

The infrastructure is in place. Now it's just mechanical replacement of log calls.
