.PHONY: docs docs-build docs-clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  docs       - Serve documentation locally with live reload"
	@echo "  docs-build - Build documentation site"
	@echo "  docs-clean - Clean documentation build artifacts"

# Serve documentation with live reload
docs:
	@echo "Starting documentation server..."
	@echo "Documentation will be available at http://127.0.0.1:8000"
	zensical serve

# Build documentation
docs-build:
	@echo "Building documentation..."
	zensical build

# Clean documentation build artifacts
docs-clean:
	@echo "Cleaning documentation build artifacts..."
	rm -rf site/
