# Getting Started with ask-ranger

This guide walks you through your first feature using the 5-step workflow.

## Prerequisites

After running `make setup` and installing Superpowers, verify everything works:

```bash
make status
```

All 4 tools should show as installed (GitNexus, OpenSpec, Superpowers, AgentShield).

---

## Your First Feature — Step by Step

### Step 1 — Spec

Open your AI tool in the target repo and run:

```
/opsx:propose <describe what you want to build>
```

The AI creates three files:
- `openspec/changes/<name>/proposal.md` — what and why
- `openspec/changes/<name>/design.md` — how
- `openspec/changes/<name>/tasks.md` — implementation tasks (2–5 min each)

Read and approve the spec. Ask the AI to revise anything unclear.

```bash
git add openspec/changes/<name>/
git commit -m "spec: <feature name>"
```

---

### Step 2 — Impact Analysis

The AI runs this automatically before coding. It uses GitNexus to find what will be affected:

```
gitnexus_impact({target: "SymbolName", direction: "upstream"})
```

The AI reports which modules are affected. You decide:
- 3 or fewer modules → one PR
- More than 3 → split into smaller PRs

---

### Step 3 — Brainstorm + Plan

```
/superpowers:brainstorming
```

The AI proposes 2–3 approaches with trade-offs. You choose one.

```
/superpowers:writing-plans
```

The AI creates a detailed implementation plan. Review it — every task must have a verification step before you approve.

---

### Step 4 — Execute

```
/superpowers:executing-plans
```

The AI implements each task using TDD (tests first, then code), commits after each task, and reports when done. If a task fails 3 times, the AI stops and asks for direction.

---

### Step 5 — Review + Ship

```
/superpowers:requesting-code-review
```
AI reviews its own output against the methodology.

```bash
make check-artifacts   # verify spec artifacts are complete
make scan              # security scan
git push origin feature/<name>
```

Create a PR, review it, merge. Then close the change:

```
/opsx:archive
```

---

## Platform Notes

The `/opsx:*` and `/superpowers:*` commands work across all supported AI tools:

| Command group | Claude Code | Antigravity | GitHub Copilot |
|---|---|---|---|
| `/opsx:propose` `/opsx:apply` `/opsx:archive` | Yes | Yes | Yes (via agent) |
| `/superpowers:brainstorming` `/superpowers:writing-plans` `/superpowers:executing-plans` | Yes (plugin) | Yes | Yes (via agent) |
| GitNexus MCP tools | Yes | Yes | Partial |

For Claude Code: install Superpowers with `/plugin install superpowers@claude-plugins-official`.

For Antigravity: skills are in `.agent/skills/`, workflows in `.agent/workflows/` — loaded automatically.

For GitHub Copilot: agent instructions are in `.github/copilot-instructions.md` and `.github/prompts/`.

---

## Daily Commands

| Command | When to use |
|---|---|
| `make index` | After every merge |
| `make check-artifacts` | Before shipping — confirm spec artifacts are complete |
| `make scan` | Before every push |
| `make review` | Full 3-layer review before PR |
| `make update` | Pull latest CLAUDE.md + AGENTS.md from ask-ranger |
| `make status` | Check all tools are working |

---

## Anti-Patterns

| Do not | Instead |
|---|---|
| Start coding without a spec | `/opsx:propose` first |
| Skip brainstorm | `/superpowers:brainstorming` before planning |
| Push without review | `make review` + `make scan` before every PR |
| Forget to archive | `/opsx:archive` after every merge |
