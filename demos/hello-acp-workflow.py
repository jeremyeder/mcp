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

MARKER = "HELLO_ACP_SUCCESS"

PLAN = f"""\
# Plan: Hello ACP

## Objective
Prove the full ACP pipeline works end-to-end.

## Steps
1. Create `/workspace/hello_acp.py` with: `print('{MARKER}')`
2. Run it: `python3 /workspace/hello_acp.py`
3. Confirm output contains `{MARKER}`
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


async def wait_for_phase(client: ACPClient, project: str, session_name: str, target: str) -> str | None:
    """Poll until session reaches target phase. Returns the phase reached."""
    elapsed = 0
    last_phase = None
    while elapsed < POLL_TIMEOUT:
        sessions = await client.list_sessions(project=project)
        match = next(
            (s for s in sessions.get("sessions", []) if s["metadata"]["name"] == session_name),
            None,
        )
        if match:
            phase = match.get("status", {}).get("phase")
            if phase != last_phase:
                progress(f"Phase: {phase}")
                last_phase = phase
            if phase == target:
                return phase
            if phase in ("Failed", "Error"):
                return phase
        await asyncio.sleep(POLL_INTERVAL)
        elapsed += POLL_INTERVAL
    return last_phase


async def wait_for_marker(client: ACPClient, project: str, session_name: str) -> bool:
    """Poll logs until MARKER appears or timeout."""
    elapsed = 0
    last_len = 0
    while elapsed < POLL_TIMEOUT:
        logs_result = await client.get_session_logs(
            project=project, session=session_name, container="ambient-code-runner",
        )
        logs_text = logs_result.get("logs", "")
        if len(logs_text) != last_len:
            progress(f"Logs: {len(logs_text)} chars")
            last_len = len(logs_text)
        if MARKER in logs_text:
            return True
        await asyncio.sleep(POLL_INTERVAL)
        elapsed += POLL_INTERVAL
    return False


async def main() -> int:
    client = ACPClient()

    # Resolve project
    default_cluster = client.config.get("default_cluster")
    cluster_config = client.config.get("clusters", {}).get(default_cluster, {})
    project = cluster_config.get("default_project")
    if not project:
        print(f"No default_project configured for cluster '{default_cluster}'")
        return 1

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
        print(f"  You can close your laptop, go to lunch, whatever.")
        print(f"  The work continues without you.{RESET}\n")
        info("Check status", f"acp_list_sessions(project={project!r})")
        info("View logs", f"acp_get_session_logs(session={session_name!r})")
        print()

        # ── Step 4: Check session status ──
        step(4, "Check session status")
        print(f"  {DIM}acp_list_sessions(project={project!r}){RESET}\n")

        phase = await wait_for_phase(client, project, session_name, "Running")
        if phase in ("Failed", "Error"):
            warn(f"Session entered phase '{phase}'")
            return 1
        if phase != "Running":
            warn(f"Session never reached Running (last: {phase})")
            return 1

        # Show session metadata once running
        sessions = await client.list_sessions(project=project)
        match = next(
            (s for s in sessions.get("sessions", []) if s["metadata"]["name"] == session_name),
            None,
        )
        if match:
            ok("Session is running")
            info("Session", session_name)
            info("Display name", match.get("spec", {}).get("displayName", ""))
            info("Phase", f"{BOLD}{match.get('status', {}).get('phase')}{RESET}")
            info("Created", match["metadata"].get("creationTimestamp", ""))
            info("Model", match.get("spec", {}).get("llmConfig", {}).get("model", ""))
            repos = match.get("spec", {}).get("repos", [])
            if repos:
                for r in repos:
                    info("Repo", r.get("input", {}).get("url", ""))
        print()

        # ── Step 5: Wait for completion via logs ──
        step(5, "Verify output")
        print(f"  {DIM}acp_get_session_logs(session={session_name!r}){RESET}\n")

        found = await wait_for_marker(client, project, session_name)

        if found:
            ok(f"Found marker: {MARKER}")
        else:
            warn(f"Marker '{MARKER}' not found after {POLL_TIMEOUT}s")
            return 1

        # ── Done ──
        print(f"\n{GREEN}{'═' * 80}")
        print(f"  SUCCESS — Full pipeline verified")
        print(f"  Plan -> acp_create_session -> K8s CR -> Operator -> Runner Pod -> Claude -> Done")
        print(f"{'═' * 80}{RESET}\n")
        return 0

    finally:
        # Cleanup
        await client.delete_session(project=project, session=session_name)


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
