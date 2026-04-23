# ask-ranger — Agentic SDLC Kit for solo developers
# Day-to-day operations via Make targets.
# Run `make help` for available commands.

.PHONY: help sync test index scan scan-deep check-artifacts review review-checklist archive status clean

SHELL := /bin/bash

# ── Setup ──────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

sync: ## Regenerate platform-specific workflow files from canonical workflows/
	@bash scripts/sync-platforms.sh

# ── Knowledge Graph ────────────────────────────────────────────────────────────

index: ## Re-index codebase (GitNexus). Preserves embeddings if already present.
	@echo "==> Re-indexing codebase..."
	@FLAGS=""; \
	if [ -f .gitnexus/meta.json ] && command -v jq >/dev/null 2>&1; then \
		COUNT=$$(jq -r '.stats.embeddings // 0' .gitnexus/meta.json 2>/dev/null || echo 0); \
		if [ "$$COUNT" != "0" ] && [ -n "$$COUNT" ]; then \
			echo "    embeddings detected ($$COUNT) — preserving via --embeddings"; \
			FLAGS="--embeddings"; \
		fi; \
	fi; \
	npx gitnexus analyze $$FLAGS
	@echo "==> Index complete"

# ── Security ───────────────────────────────────────────────────────────────────

scan: ## Run AgentShield security scan
	npx ecc-agentshield scan

scan-deep: ## Run AgentShield deep scan (Opus + streaming)
	npx ecc-agentshield scan --opus --stream

# ── Review ─────────────────────────────────────────────────────────────────────

check-artifacts: ## Check OpenSpec artifact completeness (proposal, design, tasks)
	npx openspec validate --all

review-checklist: ## Print 3-layer review checklist and run artifact check + re-index
	@echo "==> Layer 1: AI methodology review (manual)"
	@echo "    Run in your AI tool: /superpowers:requesting-code-review"
	@echo ""
	@echo "==> Layer 2: Artifact completeness"
	npx openspec validate --all
	@echo ""
	@echo "==> Layer 3: Re-index knowledge graph"
	$(MAKE) index
	@echo ""
	@echo "==> 3-layer review checklist complete (layer 1 runs in your AI tool)"

review: review-checklist ## Alias for review-checklist (kept for backward compatibility)

# ── Spec Lifecycle ─────────────────────────────────────────────────────────────

archive: ## Archive specs + re-index (post-merge)
	npx openspec archive
	$(MAKE) index
	@echo "==> Archived and re-indexed"

# ── Status ─────────────────────────────────────────────────────────────────────

status: ## Show status of all installed tools
	@echo "==> GitNexus"
	@npx -y gitnexus status 2>/dev/null || echo "    [not indexed — run: make index]"
	@echo ""
	@echo "==> OpenSpec"
	@npx -y openspec list 2>/dev/null || echo "    [no active changes]"
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

clean: ## Clean GitNexus index (requires confirmation; set CI=1 to auto-confirm)
	@if [ "$(CI)" = "1" ] || [ "$(FORCE)" = "1" ]; then \
		gitnexus clean; \
	else \
		read -p "This will remove the GitNexus index. Continue? [y/N] " confirm && \
		[ "$$confirm" = "y" ] && gitnexus clean || echo "Aborted."; \
	fi
