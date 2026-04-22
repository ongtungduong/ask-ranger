# asf-devflow — ASF lite edition for solo developers
# Day-to-day operations via Make targets.
# Run `make help` for available commands.

.PHONY: help setup update index scan scan-deep check-artifacts review archive status clean

SHELL := /bin/bash

# ── Setup ──────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## Setup asf-devflow. Current dir by default, or: make setup TARGET=/path/to/repo
	@bash scripts/setup.sh "$(TARGET)"

update: ## Pull latest CLAUDE.md + AGENTS.md from asf-devflow (safe to re-run)
	@bash scripts/setup.sh "$(TARGET)"
	@echo ""
	@echo "Note: Makefile, githooks, .claude, .github, .agent, docs are skipped if already"
	@echo "      present. Delete them first to force a full update."

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

# ── Review ─────────────────────────────────────────────────────────────────────

check-artifacts: ## Check OpenSpec artifact completeness (proposal, design, tasks)
	openspec validate --all

review: ## Run 3-layer review (AI methodology + artifact check + re-index)
	@echo "==> Layer 1: AI methodology review"
	@echo "    Run in your AI tool: /superpowers:code-review"
	@echo ""
	@echo "==> Layer 2: Artifact completeness"
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

status: ## Show status of all installed tools
	@echo "==> GitNexus"
	@gitnexus status 2>/dev/null || echo "    [not indexed — run: make index]"
	@echo ""
	@echo "==> OpenSpec"
	@openspec list 2>/dev/null || echo "    [no active changes]"
	@echo ""
	@echo "==> Superpowers"
	@if ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/ &>/dev/null; then \
		VER=$$(ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/ | tail -1); \
		echo "    installed (v$$VER)"; \
	else \
		echo "    [not installed — run in Claude Code: /plugin install superpowers@claude-plugins-official]"; \
	fi
	@echo ""
	@echo "==> AgentShield hooks"
	@if jq -e '.hooks.PreToolUse | length > 0' ~/.claude/settings.json &>/dev/null; then \
		COUNT=$$(jq '.hooks.PreToolUse | length' ~/.claude/settings.json); \
		echo "    $$COUNT pre-tool hooks active"; \
	else \
		echo "    [no hooks — run: make setup]"; \
	fi

# ── Maintenance ────────────────────────────────────────────────────────────────

clean: ## Clean GitNexus index (requires confirmation)
	@read -p "This will remove the GitNexus index. Continue? [y/N] " confirm && \
		[ "$$confirm" = "y" ] && gitnexus clean || echo "Aborted."
