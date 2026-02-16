"""Hello ACP — first live session submission via acp_create_session.

This integration test proves the full pipeline:
  MCP tool → K8s CR → operator → runner pod → Claude execution → completion

Requires: live cluster access (oc login) and a valid clusters.yaml config.

Run with:
    pytest tests/integration/test_hello_acp.py -m integration -v
"""

import asyncio

import pytest

from mcp_acp.client import ACPClient

MARKER = "HELLO_ACP_SUCCESS"

PROMPT = (
    "Write a Python script at /workspace/hello_acp.py containing exactly:\n"
    f"print('{MARKER}')\n"
    "Then run it with: python3 /workspace/hello_acp.py\n"
    "Do nothing else."
)

POLL_INTERVAL_SECONDS = 10
POLL_TIMEOUT_SECONDS = 300  # 5 minutes
SESSION_TIMEOUT_SECONDS = 300


@pytest.fixture
def client() -> ACPClient:
    """Create a live ACPClient using real cluster config."""
    return ACPClient()


def _default_project(client: ACPClient) -> str:
    """Resolve default project from clusters.yaml config."""
    default_cluster = client.config.get("default_cluster")
    cluster_config = client.config.get("clusters", {}).get(default_cluster, {})
    project = cluster_config.get("default_project")
    if not project:
        raise ValueError(f"No default_project configured for cluster '{default_cluster}'")
    return project


@pytest.mark.integration
@pytest.mark.asyncio
async def test_hello_acp(client: ACPClient) -> None:
    """Submit a hello-world session and verify it runs and produces marker output."""
    project = _default_project(client)

    # 1. Create session
    result = await client.create_session(
        project=project,
        initial_prompt=PROMPT,
        display_name="hello-acp-test",
        timeout=SESSION_TIMEOUT_SECONDS,
    )
    assert result.get("created"), f"Session creation failed: {result}"

    session_name: str = result["session"]

    try:
        # 2. Poll until session is Running (pod started, prompt being processed)
        phase = None
        elapsed = 0
        while elapsed < POLL_TIMEOUT_SECONDS:
            sessions = await client.list_sessions(project=project)
            match = next(
                (s for s in sessions.get("sessions", []) if s["metadata"]["name"] == session_name),
                None,
            )
            if match:
                phase = match.get("status", {}).get("phase")
                if phase == "Running":
                    break
                if phase in ("Failed", "Stopped"):
                    pytest.fail(f"Session '{session_name}' entered phase '{phase}' before Running")
            await asyncio.sleep(POLL_INTERVAL_SECONDS)
            elapsed += POLL_INTERVAL_SECONDS

        assert phase == "Running", (
            f"Session '{session_name}' never reached Running (last phase: '{phase}')"
        )

        # 3. Poll logs until marker appears (Claude processes the prompt)
        marker_found = False
        elapsed = 0
        logs_text = ""
        while elapsed < POLL_TIMEOUT_SECONDS:
            logs_result = await client.get_session_logs(
                project=project, session=session_name, container="ambient-code-runner",
            )
            logs_text = logs_result.get("logs", "")
            if MARKER in logs_text:
                marker_found = True
                break
            await asyncio.sleep(POLL_INTERVAL_SECONDS)
            elapsed += POLL_INTERVAL_SECONDS

        assert marker_found, (
            f"Marker '{MARKER}' not found in session logs after {POLL_TIMEOUT_SECONDS}s "
            f"(got {len(logs_text)} chars of log output)"
        )

    finally:
        # 4. Cleanup — delete session regardless of outcome
        await client.delete_session(project=project, session=session_name)
