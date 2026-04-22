# ask-ranger

A spec-driven development framework for solo developers. Write specs first, execute with AI, review in 3 layers.

**ask-ranger** is the **ASK (Agentic SDLC Kit)** — a lightweight setup for individual developers working on personal projects.

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

**Required:** Node.js ≥ 18, Git.
**Auto-installed on macOS/Linux** by `setup.sh`: jq, gitleaks. Native Windows is not supported — use WSL2.

```bash
git clone <this-repo> ask-ranger

# Apply to an existing repo:
make -C ask-ranger setup TARGET=/path/to/your-repo

# Or use ask-ranger itself as your working repo:
cd ask-ranger && make setup
```

The tested compatibility range for the installed CLIs lives in this repo's
[`package.json`](package.json) under `peerDependencies` (OpenSpec, GitNexus,
AgentShield). `setup.sh` pulls `@latest`, so expect minor drift between
releases; check the CHANGELOG before `make update` if something breaks.

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
| `.gitignore` | ask-ranger entries appended once |
| `core.hooksPath` | Set to `githooks/` |
| OpenSpec | Initialized in target repo |
| GitNexus | Codebase indexed |
| AgentShield | Hooks merged into `~/.claude/settings.json` |

### Updating

When ask-ranger releases updates, pull the latest system prompts:

```bash
make update
```

This overwrites `CLAUDE.md` and `AGENTS.md`. Other files (Makefile, hooks, etc.) are skipped — delete them first if you want a full update.

---

## Daily Operations

| Command | What It Does |
|---|---|
| `make update-prompts` | Pull latest CLAUDE.md + AGENTS.md from ask-ranger (alias: `make update`) |
| `make sync` | Regenerate platform-specific workflow files from canonical `workflows/` |
| `make index` | Re-index codebase (GitNexus) — run after every merge |
| `make check-artifacts` | Check OpenSpec artifact completeness |
| `make review-checklist` | Run 3-layer review checklist (alias: `make review`) |
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
├── workflows/               # Canonical source-of-truth for opsx workflows
├── .agent/                  # Generated Antigravity skills and workflows
├── .claude/
│   ├── commands/opsx/       # Generated Claude Code slash commands
│   ├── skills/              # Generated Claude Code skills
│   └── settings.json        # AgentShield hooks (uses gitleaks)
├── .github/                 # Generated Copilot skills + instructions
├── docs/
│   └── superpowers/         # Implementation plans and specs
├── githooks/                # Git hooks (pre-push security scan)
├── openspec/                # OpenSpec workspace (changes, specs)
├── scripts/
│   ├── setup.sh             # Unified setup script
│   ├── sync-platforms.sh    # Regenerate platform-specific files
│   ├── session-end-check.sh # Session-stop gitleaks scan
│   └── hooks/               # Claude Code PreToolUse hooks
├── CLAUDE.md                # AI system prompt — workflow rules
├── GETTING_STARTED.md       # Step-by-step first-feature guide
├── LICENSE                  # MIT
└── Makefile                 # All day-to-day operations
```

> Files in `.claude/commands/opsx/`, `.claude/skills/openspec-*`, `.agent/skills/openspec-*`, `.agent/workflows/opsx-*`, `.github/skills/openspec-*`, and `.github/prompts/opsx-*` are **generated** from `workflows/`. Edit the canonical source there, then run `make sync`.
