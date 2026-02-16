#!/bin/bash
cd /Users/jeder/repos/mcp
PYTHONPATH=".:src:$PYTHONPATH" .venv/bin/python demos/hello-acp-workflow.py
