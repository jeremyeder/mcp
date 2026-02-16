"""Hello ACP — first live session submission via acp_create_session.

This integration test proves the full pipeline:
  MCP tool → public API → K8s CR → operator → runner pod → Claude execution → completion

Requires: live cluster access and a valid clusters.yaml config with token.

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
    default_cluster = client.clusters_config.default_cluster
    if not default_cluster:
        raise ValueError("No default_cluster configured")
    cluster = client.clusters_config.clusters.get(default_cluster)
    if not cluster or not cluster.default_project:
        raise ValueError(f"No default_project configured for cluster '{default_cluster}'")
    return cluster.default_project


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
        # 2. Poll until session status changes from "creating"
        status = None
        elapsed = 0
        while elapsed < POLL_TIMEOUT_SECONDS:
            session_data = await client.get_session(project=project, session=session_name)
            status = session_data.get("status", "")
            if status.lower() == "running":
                break
            if status.lower() in ("failed", "stopped"):
                pytest.fail(f"Session '{session_name}' entered status '{status}' before running")
            await asyncio.sleep(POLL_INTERVAL_SECONDS)
            elapsed += POLL_INTERVAL_SECONDS

        assert status and status.lower() == "running", (
            f"Session '{session_name}' never reached running (last status: '{status}')"
        )

    finally:
        # 3. Cleanup — delete session regardless of outcome
        await client.delete_session(project=project, session=session_name)
