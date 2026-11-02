.PHONY: release help

# Default target
help:
	@echo "Usage:"
	@echo "  make release VERSION=1.0.3   Build, sign, and zip for macOS"

release:
ifndef VERSION
	$(error VERSION is required. Usage: make release VERSION=1.0.3)
endif
	@bash scripts/build-release-macos.sh $(VERSION)
