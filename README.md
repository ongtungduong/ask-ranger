# ASF — Agentic SDLC Framework

A spec-driven development framework. Write specs first, execute with AI, review
in 3 layers. 5-tool stack, $20/month total.

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

**Supported platforms:** Claude Code (primary) | GitHub Copilot | Antigravity

## Setup

Requires **Node.js ≥ 18**, **Git**, **jq**, and a **Claude Code subscription** ($20/mo).

One script handles both new repos and existing repos with code. It is idempotent — safe to re-run.

```bash
git clone <this-repo> agentic-sdlc-framework

# Option A — apply to an existing repo
make -C agentic-sdlc-framework setup TARGET=/path/to/your-repo

# Option B — use ASF itself as your working repo
cd agentic-sdlc-framework && make setup
```

What the script does in the target repo:

| File / Directory | Behavior |
|---|---|
| `CLAUDE.md`, `AGENTS.md` | Always overwritten (ASF system prompts) |
| `Makefile`, `githooks/`, `.claude/`, `.github/`, `.agent/`, `docs/` | Copied only if not present |
| `.gitignore` | ASF entries appended once (marker-based) |
| `core.hooksPath` | Set to `githooks/` |
| OpenSpec | `openspec init` in target |
| GitNexus | `gitnexus analyze` to build code index |
| AgentShield | Hooks merged into `~/.claude/settings.json` |

One manual step inside Claude Code:

```
/plugin install superpowers@claude-plugins-official
```

Restart Claude Code after installing Superpowers. Then run `make status` to verify.

## Directory Layout

```
.
├── .agent/                  # Antigravity config
├── .claude/
│   └── settings.json        # AgentShield hooks: block secrets, protect config
├── .github/                 # GitHub Copilot config
├── docs/
│   └── superpowers/         # Design specs and implementation plans
├── githooks/                # Git hooks (pre-push security scan)
├── openspec/                # OpenSpec workspace (proposals, tasks, verification)
├── scripts/
│   └── setup.sh             # Unified setup (called by make setup)
├── CLAUDE.md                # Claude Code system prompt — workflow rules
└── Makefile                 # All day-to-day operations
```

## Daily Operations

| Command | What It Does |
|---|---|
| `make setup [TARGET=...]` | Install/update ASF in current dir or target repo |
| `make index` | Re-index codebase (GitNexus) — run after every merge |
| `make verify` | Check implementation against OpenSpec specs |
| `make review` | Run 3-layer review |
| `make scan` | Run AgentShield security scan |
| `make status` | Show status of installed tools |

## Tools

| Tool | What It Does | Cost |
|---|---|---|
| **Claude Code** | AI coding agent — primary interface | $20/mo |
| **OpenSpec** | Spec-driven development: proposals, specs, tasks, verification | Free |
| **GitNexus** | Code knowledge graph via MCP — impact analysis, dependency queries | Free |
| **Superpowers** | Methodology engine: brainstorm, plan, TDD execution, code review | Free |
| **AgentShield** | Security scanner + git hooks (block secrets, protect config) | Free |

## Workflow

Every feature follows a **5-step cycle**: spec → impact analysis → brainstorm+plan
→ execute → review+ship.

See `CLAUDE.md` for the full workflow rules and quick-reference command table.

## Example: Building a New Feature

**Scenario:** Add a feature to "export reports to PDF".

---

**Step 1 — Spec** · *You do this*

```
/opsx:propose export reports to PDF
```

> AI creates a spec file with task lists, edge cases, and acceptance criteria. You review and approve.

---

**Step 2 — Impact Analysis** · *AI runs this automatically*

AI runs GitNexus to find affected modules:

```
gitnexus_impact({target: "ReportService", direction: "upstream"})
```

> AI reports: "3 modules depend on ReportService. Recommend splitting into 2 PRs."
> You decide: split the PR or keep it as one.

---

**Step 3 — Brainstorm + Plan** · *AI guides, you approve*

```
/superpowers:brainstorm
```

> AI proposes 3 approaches (wkhtmltopdf / Puppeteer / server-side LaTeX), analyzes trade-offs, and recommends Puppeteer.
> You choose an approach → AI creates an implementation plan with 2-5 minute tasks.
> You review the plan and approve.

---

**Step 4 — Execute** · *AI does it, you monitor*

```
/superpowers:execute-plan
```

> AI codes each task using TDD (write tests first, implement after), and commits after each task.
> If a task fails 3 times, AI stops and reports back so you can decide the direction.

---

**Step 5 — Review + Ship** · *AI does it, you approve merge*

```
/superpowers:code-review   # AI review methodology
make verify                # OpenSpec verifies spec compliance
make scan                  # AgentShield runs security scans
git push origin feature/export-pdf
```

> You review the PR and merge.

---

| Step | Human | AI |
|---|---|---|
| Spec | Describe the feature, approve spec | Create spec and edge cases |
| Impact | Decide whether to split PRs | Run blast radius analysis |
| Brainstorm | Answer questions, choose approach, approve plan | Propose options, create plan |
| Execute | Monitor and unblock if AI gets stuck | Code, test, and commit each task |
| Review | Review PR and approve merge | Run 3-layer review and security scan |

---

**Core principles:** Spec before code. Context is king. 3-layer review before every PR.
