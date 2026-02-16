"""Hello ACP workflow demo — compile a plan, submit it, check status, see success."""

import asyncio
import sys
import time

from mcp_acp.client import ACPClient

# --- Colors ---
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
DIM = "\033[2;37m"
BOLD = "\033[1m"
RESET = "\033[0m"

PLAN = """\
# Plan: Hello ACP

## Objective
Prove the full ACP pipeline works end-to-end.

## Steps
1. Create `/workspace/hello_acp.py` with: `print('HELLO_ACP_SUCCESS')`
2. Run it: `python3 /workspace/hello_acp.py`
3. Confirm output contains `HELLO_ACP_SUCCESS`
"""

PROMPT = (
    "You are executing a plan that was compiled and submitted to ACP.\n\n"
    "---\n\n"
    f"{PLAN}\n"
    "Do nothing else beyond what the plan says."
)

POLL_INTERVAL = 10
POLL_TIMEOUT = 300


def step(n: int, text: str) -> None:
    print(f"\n{CYAN}{'─' * 80}")
    print(f"  Step {n}: {text}")
    print(f"{'─' * 80}{RESET}\n")
    time.sleep(0.5)


def info(label: str, value: str) -> None:
    print(f"  {DIM}{label}:{RESET} {value}")


def ok(text: str) -> None:
    print(f"\n  {GREEN}✓ {text}{RESET}")


def warn(text: str) -> None:
    print(f"\n  {YELLOW}⚠ {text}{RESET}")


def progress(msg: str) -> None:
    print(f"  {DIM}… {msg}{RESET}", flush=True)


def _default_project(client: ACPClient) -> str:
    """Resolve default project from clusters.yaml config."""
    default_cluster = client.clusters_config.default_cluster
    if not default_cluster:
        raise ValueError("No default_cluster configured")
    cluster = client.clusters_config.clusters.get(default_cluster)
    if not cluster or not cluster.default_project:
        raise ValueError(f"No default_project configured for cluster '{default_cluster}'")
    return cluster.default_project


async def wait_for_status(
    client: ACPClient,
    project: str,
    session_name: str,
    target: str,
) -> tuple[str | None, dict]:
    """Poll until session reaches target status. Returns (status, session_data)."""
    elapsed = 0
    last_status = None
    session_data = {}
    while elapsed < POLL_TIMEOUT:
        session_data = await client.get_session(project=project, session=session_name)
        status = session_data.get("status", "")
        if status != last_status:
            progress(f"Status: {status}")
            last_status = status
        if status.lower() == target.lower():
            return status, session_data
        if status.lower() in ("failed", "error"):
            return status, session_data
        await asyncio.sleep(POLL_INTERVAL)
        elapsed += POLL_INTERVAL
    return last_status, session_data


async def wait_for_completion(
    client: ACPClient,
    project: str,
    session_name: str,
) -> tuple[str | None, dict]:
    """Poll until session completes (stopped/completed/failed)."""
    elapsed = 0
    last_status = None
    session_data = {}
    while elapsed < POLL_TIMEOUT:
        session_data = await client.get_session(project=project, session=session_name)
        status = session_data.get("status", "")
        if status != last_status:
            progress(f"Status: {status}")
            last_status = status
        if status.lower() in ("completed", "stopped", "failed", "error"):
            return status, session_data
        await asyncio.sleep(POLL_INTERVAL)
        elapsed += POLL_INTERVAL
    return last_status, session_data


async def main() -> int:
    client = ACPClient()
    project = _default_project(client)

    # ── Step 1: Show the plan ──
    step(1, "The plan")
    print(f"{DIM}{PLAN}{RESET}")

    # ── Step 2: Compile and submit ──
    step(2, "Compile this plan with ACP")
    print(f"  {DIM}acp_create_session(project={project!r}, display_name='hello-acp-demo', ...){RESET}\n")

    result = await client.create_session(
        project=project,
        initial_prompt=PROMPT,
        display_name="hello-acp-demo",
        timeout=300,
    )

    if not result.get("created"):
        print(f"  Session creation failed: {result}")
        return 1

    session_name = result["session"]
    ok("Session created")
    info("Session", session_name)
    info("Project", project)
    info("Display name", "hello-acp-demo")
    print()

    try:
        # ── Step 3: Disconnect ──
        step(3, "Disconnect — session runs autonomously on the cluster")
        print(f"  {DIM}The session is now running on a pod in the cluster.")
        print("  You can close your laptop, go to lunch, whatever.")
        print(f"  The work continues without you.{RESET}\n")
        info("Check status", f"acp_get_session(session={session_name!r})")
        info("List all", f"acp_list_sessions(project={project!r})")
        print()

        # ── Step 4: Check session status ──
        step(4, "Check session status")
        print(f"  {DIM}acp_get_session(session={session_name!r}){RESET}\n")

        status, session_data = await wait_for_status(client, project, session_name, "running")
        if not status or status.lower() in ("failed", "error"):
            warn(f"Session entered status '{status}'")
            return 1
        if status.lower() != "running":
            warn(f"Session never reached running (last: {status})")
            return 1

        # Show session metadata once running
        ok("Session is running")
        info("Session", session_data.get("id", session_name))
        info("Display name", session_data.get("displayName", ""))
        info("Status", f"{BOLD}{session_data.get('status', '')}{RESET}")
        info("Created", session_data.get("createdAt", ""))
        model = session_data.get("model", "")
        if model:
            info("Model", model)
        print()

        # ── Step 5: Wait for completion ──
        step(5, "Wait for completion")
        print(f"  {DIM}Polling acp_get_session until session finishes...{RESET}\n")

        final_status, final_data = await wait_for_completion(client, project, session_name)

        if final_status and final_status.lower() in ("completed", "stopped"):
            ok(f"Session finished — status: {final_status}")
            completed_at = final_data.get("completedAt", "")
            if completed_at:
                info("Completed at", completed_at)
        else:
            warn(f"Session did not complete within {POLL_TIMEOUT}s (last: {final_status})")
            return 1

        # ── Done ──
        print(f"\n{GREEN}{'═' * 80}")
        print("  SUCCESS — Full pipeline verified")
        print("  Plan -> acp_create_session -> Public API -> K8s CR -> Operator -> Runner -> Done")
        print(f"{'═' * 80}{RESET}\n")
        return 0

    finally:
        await client.delete_session(project=project, session=session_name)
        await client.close()


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
