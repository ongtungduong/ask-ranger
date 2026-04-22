# asf-devflow

A spec-driven development framework for solo developers. Write specs first, execute with AI, review in 3 layers.

Part of the **ASF (Agentic SDLC Framework)** family — lite edition, targeting individual developers working on personal projects.

**Stack:** OpenSpec · GitNexus (MCP) · Claude Code + Superpowers + AgentShield  
**Cost:** $20/month (Claude Code subscription) — all other tools are free  
**Platforms:** Claude Code (primary) | Antigravity | GitHub Copilot

---

## How It Works

Every feature follows a 5-step cycle:

```
Spec → Impact Analysis → Brainstorm+Plan → Execute → Review+Ship
```

See [GETTING_STARTED.md](GETTING_STARTED.md) for a step-by-step walkthrough.

---

## Setup

Requires **Node.js ≥ 18**, **Git**, and **jq**.

```bash
git clone <this-repo> asf-devflow

# Apply to an existing repo:
make -C asf-devflow setup TARGET=/path/to/your-repo

# Or use asf-devflow itself as your working repo:
cd asf-devflow && make setup
```

One manual step inside your AI tool:

```
/plugin install superpowers@claude-plugins-official
```

Restart your AI tool, then verify:

```bash
make status
```

### What gets installed

| File / Directory | Behavior |
|---|---|
| `CLAUDE.md`, `AGENTS.md` | Always overwritten (AI system prompts) |
| `Makefile`, `githooks/`, `.claude/`, `.github/`, `.agent/`, `docs/` | Copied only if not present |
| `.gitignore` | asf-devflow entries appended once |
| `core.hooksPath` | Set to `githooks/` |
| OpenSpec | Initialized in target repo |
| GitNexus | Codebase indexed |
| AgentShield | Hooks merged into `~/.claude/settings.json` |

### Updating

When asf-devflow releases updates, pull the latest system prompts:

```bash
make update
```

This overwrites `CLAUDE.md` and `AGENTS.md`. Other files (Makefile, hooks, etc.) are skipped — delete them first if you want a full update.

---

## Daily Operations

| Command | What It Does |
|---|---|
| `make update` | Pull latest CLAUDE.md + AGENTS.md from asf-devflow |
| `make index` | Re-index codebase (GitNexus) — run after every merge |
| `make check-artifacts` | Check OpenSpec artifact completeness |
| `make review` | Run full 3-layer review |
| `make scan` | Run AgentShield security scan |
| `make status` | Show status of all installed tools |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  SPEC              OpenSpec (propose, verify, archive)               │
├──────────────────────────────────────────────────────────────────────┤
│  CODE INTEL        GitNexus (MCP — impact, context, query)           │
├──────────────────────────────────────────────────────────────────────┤
│  IMPLEMENTATION    Claude Code + Superpowers + AgentShield           │
└──────────────────────────────────────────────────────────────────────┘
```

## Directory Layout

```
.
├── .agent/                  # Antigravity skills and workflows
├── .claude/
│   └── settings.json        # AgentShield hooks
├── .github/                 # GitHub Copilot instructions and prompts
├── docs/
│   └── superpowers/         # Implementation plans and specs
├── githooks/                # Git hooks (pre-push security scan)
├── openspec/                # OpenSpec workspace (changes, specs)
├── scripts/
│   └── setup.sh             # Unified setup script
├── CLAUDE.md                # AI system prompt — workflow rules
├── GETTING_STARTED.md       # Step-by-step first-feature guide
└── Makefile                 # All day-to-day operations
```

---

## Related

- **asf-devflow** (this repo) — lite edition for solo developers
- **asf-enterprise** (planned) — team edition with BMAD-based multi-agent orchestration
