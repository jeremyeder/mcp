# MCP-ACP Trigger Phrases

These phrases will reliably trigger the MCP-ACP server in Claude Desktop/Code.

## ✅ Phrases That Work

### Viewing Sessions
- "Show my **ACP** sessions"
- "List my **AgenticSessions**"
- "Get my **ambient** sessions"
- "What **ACP** sessions are in jeder-workspace?"
- "Show me all **AgenticSession** resources"
- "List **ambient** container platform sessions"

### Session Details
- "Get details for **ACP** session-name"
- "Show **AgenticSession** session-name"
- "What's the status of my **ambient** session?"
- "Get transcript for **ACP** session-name"

### Managing Sessions
- "Stop **ACP** session-name"
- "Restart my **AgenticSession** session-name"
- "Delete **ambient** session-name"
- "Create a new **ACP** session"

### Authentication & Cluster
- "Check my **ACP** authentication"
- "Show **OpenShift** cluster info"
- "What **ACP** projects do I have access to?"
- "Login to **ACP** cluster"

### Using Tool Names Directly
- "Use **acp_list_sessions**"
- "Use **acp_whoami**"
- "Use **acp_get_session** with session-name"
- "Use **acp_list_projects**"

## ❌ Phrases That Don't Work

These are too generic and won't trigger the MCP-ACP server:

- "view my workspace" (too generic)
- "show my sessions" (no trigger keyword)
- "list sessions" (no trigger keyword)
- "what's in my project?" (no trigger keyword)
- "check my cluster" (no trigger keyword)

## 🎯 The Pattern

**Add one of these keywords**:
- **ACP**
- **ambient**
- **AgenticSession** (or "agentic session")
- **OpenShift** (for cluster operations)
- **acp_toolname** (explicit tool names)

## Examples for Your Setup

Based on your config (`jeder-workspace` on `vteam-stage`):

### List Your Sessions
```
Show my ACP sessions in jeder-workspace
```

### Check Authentication
```
Use acp_whoami to check my ACP authentication
```

### Get Session Details
```
Get details for ACP session session-1769698517
```

### View Specific Session
```
Show AgenticSession session-name in jeder-workspace
```

### Create New Session
```
Create a new ACP session in jeder-workspace
```

## Pro Tips

1. **Always include a trigger keyword** - ACP, ambient, AgenticSession, or OpenShift
2. **Be specific about the project** - Include "in jeder-workspace" if needed
3. **Use tool names directly** - "Use acp_list_sessions" always works
4. **Check connection first** - Start with "Use acp_whoami" to verify setup

## Your Config

Your `~/.config/acp/clusters.yaml`:
```yaml
clusters:
  vteam-stage:
    server: https://api.vteam-stage.7fpc.p3.openshiftapps.com:443
    description: "ACP Stage"
    default_project: jeder-workspace

default_cluster: vteam-stage
```

This means:
- ✅ Default project is set to `jeder-workspace`
- ✅ You don't need to specify project in every command
- ✅ The server will auto-fill `jeder-workspace` when project is not provided

## Testing

Try this to verify the MCP-ACP server is working:

```
Use acp_whoami to check my authentication
```

You should see:
```
Current Authentication Status:

Authenticated: Yes
User: [your-username]
Cluster: vteam-stage
Server: https://api.vteam-stage.7fpc.p3.openshiftapps.com:443
Project: jeder-workspace
Token Valid: Yes
```

If that works, then try:

```
Show my ACP sessions
```

This should list all AgenticSessions in your jeder-workspace project.
