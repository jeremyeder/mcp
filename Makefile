.PHONY: install clean test format check lint typecheck security build

# Install Python dependencies with pre-commit hooks
install:
	@echo "Creating virtual environment..."
	@test -d .venv || python3 -m venv .venv
	@echo "Installing package with dev dependencies..."
	@. .venv/bin/activate && pip install -e ".[dev]"
	@echo "Installing pre-commit hooks..."
	@. .venv/bin/activate && pre-commit install
	@echo "✓ Installation complete!"
	@echo ""
	@echo "Activate virtual environment with: source .venv/bin/activate"

# Clean build artifacts and caches
clean:
	rm -rf .mypy_cache .ruff_cache .pytest_cache .venv __pycache__
	rm -rf build/ dist/ *.egg-info
	rm -rf src/**/__pycache__ tests/**/__pycache__
	rm -rf .coverage htmlcov/
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -delete

# Run tests
test:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	.venv/bin/python -m pytest

# Run tests with coverage
test-cov:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	.venv/bin/python -m pytest --cov=src --cov-report=html --cov-report=term

# Format code with ruff
format:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	.venv/bin/ruff format src/ tests/

# Lint with ruff
lint:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	.venv/bin/ruff check src/ tests/

# Type check with mypy
typecheck:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	.venv/bin/mypy src/

# Security check with bandit
security:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	.venv/bin/bandit -r src/ -ll

# Run all checks (lint, typecheck, security, test)
check: lint typecheck security test
	@echo "✓ All checks passed!"

# Build wheel distribution
build:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	@. .venv/bin/activate && python -m build

# Run pre-commit hooks on all files
pre-commit:
	@if [ ! -d ".venv" ]; then \
		echo "Error: Virtual environment not found. Run 'make install' first."; \
		exit 1; \
	fi
	.venv/bin/pre-commit run --all-files

# Show help
help:
	@echo "MCP-ACP Development Commands:"
	@echo ""
	@echo "  make install      - Set up development environment"
	@echo "  make test         - Run test suite"
	@echo "  make test-cov     - Run tests with coverage"
	@echo "  make format       - Format code with ruff"
	@echo "  make lint         - Lint code with ruff"
	@echo "  make typecheck    - Type check with mypy"
	@echo "  make security     - Run security checks with bandit"
	@echo "  make check        - Run all checks"
	@echo "  make build        - Build wheel distribution"
	@echo "  make pre-commit   - Run pre-commit hooks"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make help         - Show this help message"
