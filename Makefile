# ASF — Agentic SDLC Framework
# Day-to-day operations via Make targets.
# Run `make help` for available commands.

.PHONY: help setup index scan scan-deep verify review archive status clean

SHELL := /bin/bash

# ── Setup ──────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## Setup ASF. Current dir by default, or: make setup TARGET=/path/to/repo
	@bash scripts/setup.sh $(TARGET)

# ── Knowledge Graph ────────────────────────────────────────────────────────────

index: ## Re-index codebase (GitNexus)
	@echo "==> Re-indexing codebase..."
	gitnexus analyze
	@echo "==> Index complete"

# ── Security ───────────────────────────────────────────────────────────────────

scan: ## Run AgentShield security scan
	npx ecc-agentshield scan

scan-deep: ## Run AgentShield deep scan (Opus + streaming)
	npx ecc-agentshield scan --opus --stream

# ── Review (3-layer) ──────────────────────────────────────────────────────────

verify: ## Layer 2: Check implementation against OpenSpec specs
	openspec validate --all

review: ## Run 3-layer review (methodology + spec + re-index)
	@echo "==> Layer 1: Methodology review"
	@echo "    Run in Claude Code: /superpowers:code-review"
	@echo ""
	@echo "==> Layer 2: Spec compliance"
	openspec validate --all
	@echo ""
	@echo "==> Layer 3: Re-index knowledge graph"
	$(MAKE) index
	@echo ""
	@echo "==> 3-layer review complete"

# ── Spec Lifecycle ─────────────────────────────────────────────────────────────

archive: ## Archive specs + re-index (post-merge)
	openspec archive
	$(MAKE) index
	@echo "==> Archived and re-indexed"

# ── Status ─────────────────────────────────────────────────────────────────────

status: ## Show status of all tools
	@echo "==> GitNexus"
	@gitnexus status 2>/dev/null || echo "    [not indexed]"
	@echo ""
	@echo "==> OpenSpec"
	@openspec list 2>/dev/null || echo "    [no active changes]"

# ── Maintenance ────────────────────────────────────────────────────────────────

clean: ## Clean GitNexus index (requires confirmation)
	@read -p "This will remove the GitNexus index. Continue? [y/N] " confirm && \
		[ "$$confirm" = "y" ] && gitnexus clean || echo "Aborted."
