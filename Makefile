# ask-ranger — kit development Makefile
# Day-to-day targets for working ON the kit itself.
# The target-repo Makefile (installed into user projects) lives at template/Makefile.

.PHONY: help setup sync test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: sync ## Install ask-ranger. Current dir by default, or: make setup TARGET=/path/to/repo
	@bash scripts/setup.sh "$(TARGET)"

sync: ## Regenerate platform-specific workflow files from template/workflows/
	@bash scripts/sync-platforms.sh

test: ## Run bats test suite
	@command -v bats >/dev/null || { echo "bats not found. macOS: brew install bats-core. Linux: sudo apt install bats"; exit 1; }
	@command -v jq   >/dev/null || { echo "jq not found.   macOS: brew install jq.         Linux: sudo apt install jq"; exit 1; }
	bats tests/
