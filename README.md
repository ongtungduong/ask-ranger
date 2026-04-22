# ask-ranger

**Spec-driven AI development for solo devs.** Write specs first, execute with AI, review in 3 layers.

`ask-ranger` is the **ASK (Agentic SDLC Kit)** — a lightweight scaffolding kit that wires five tools into one opinionated workflow.

**Stack:** OpenSpec · GitNexus (MCP) · Claude Code + Superpowers + AgentShield
**Cost:** $20/mo (Claude Code) — everything else is free
**Platforms:** Claude Code (primary) · Antigravity · GitHub Copilot

---

## The loop

```
Spec  →  Impact Analysis  →  Brainstorm + Plan  →  Execute  →  Review + Ship
```

Every feature goes through all five steps. The AI writes, Superpowers reviews, you approve.

→ **New here?** Read [GETTING_STARTED.md](GETTING_STARTED.md) for a full walkthrough.

---

## Install

**Required:** Node.js ≥ 18, Git.
**Auto-installed** on macOS/Linux: `jq`, `gitleaks`. Native Windows is unsupported — use WSL2.

```bash
git clone <this-repo> ask-ranger

# Apply to an existing repo
make -C ask-ranger setup TARGET=/path/to/your-repo

# Or use ask-ranger itself as your project
cd ask-ranger && make setup
```

One manual step inside Claude Code:

```
/plugin install superpowers@claude-plugins-official
```

Restart, then `make status` to verify all 4 tools are installed.

Compatibility ranges for `@fission-ai/openspec`, `gitnexus`, `ecc-agentshield` are declared in [`package.json`](package.json) under `peerDependencies`.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  SPEC              OpenSpec       (propose · verify · archive)       │
├──────────────────────────────────────────────────────────────────────┤
│  CODE INTEL        GitNexus MCP   (impact · context · query)         │
├──────────────────────────────────────────────────────────────────────┤
│  IMPLEMENTATION    Claude Code + Superpowers + AgentShield           │
└──────────────────────────────────────────────────────────────────────┘
```

## Repo layout

```
.
├── template/         # Everything setup.sh copies to a target repo
│   ├── CLAUDE.md     # AI system prompt — workflow rules + GitNexus guidance
│   ├── AGENTS.md     # Pointer to CLAUDE.md (non-Claude agents)
│   ├── Makefile      # Target-repo day-to-day operations
│   ├── workflows/    # Canonical source for opsx skills (Claude, Antigravity, Copilot)
│   ├── githooks/     # pre-push security gate
│   ├── vendor/       # Vendored AgentShield hooks (pinned SOURCE_SHA)
│   └── …             # Generated .claude/, .agent/, .github/
├── scripts/          # Kit tools: setup.sh, sync-platforms.sh, hooks/
├── tests/            # bats suite for setup + sync-platforms
├── .github/workflows # Kit CI (drift guard, shellcheck, bats, smoke)
├── Makefile          # Kit dev targets (setup, sync, test)
└── package.json      # Compatibility ranges
```

> Files under `template/.claude/commands/opsx/`, `template/.claude/skills/openspec-*`, `template/.agent/`, and `template/.github/{prompts,skills}` are **generated** from `template/workflows/`. Edit the canonical source there and run `make sync`.

---

## License

MIT — see [LICENSE](LICENSE).
