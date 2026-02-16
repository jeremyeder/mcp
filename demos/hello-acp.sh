#!/bin/bash
cd /Users/jeder/repos/mcp
.venv/bin/pytest tests/integration/test_hello_acp.py -m integration -v --no-cov
