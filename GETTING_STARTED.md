# Getting started

A hands-on walkthrough of your first feature using the 5-step workflow. Assumes `make setup` and the Superpowers plugin install are already done (see [README.md](README.md)).

Before you start, verify all four tools report installed:

```bash
make status
```

---

## The 5 steps, one feature at a time

### 1. Spec

In your AI tool (Claude Code, Antigravity, or Copilot chat):

```
/opsx:propose <describe what you want to build>
```

The AI creates three artifacts under `openspec/changes/<name>/`:

| File          | Content          |
|---------------|------------------|
| `proposal.md` | what and why     |
| `design.md`   | how              |
| `tasks.md`    | atomic tasks (2–5 min each) |

Read them. Push back on anything unclear. Then commit:

```bash
git add openspec/changes/<name>/
git commit -m "spec: <feature name>"
```

### 2. Impact analysis

The AI runs GitNexus automatically before touching code:

```
gitnexus_impact({target: "SymbolName", direction: "upstream"})
```

It reports the blast radius. Your rule of thumb:

- **≤ 3 modules affected** → one PR
- **> 3 modules** → split

### 3. Brainstorm + plan

```
/superpowers:brainstorming
```

The AI sketches 2–3 approaches with trade-offs. Pick one.

```
/superpowers:writing-plans
```

The AI writes a detailed plan. **Do not approve it until every task has a verification step.**

### 4. Execute

```
/superpowers:executing-plans
```

The AI implements each task using TDD (tests first, then code) and commits after each one. On three consecutive failures it stops and asks for direction.

### 5. Review + ship

```
/superpowers:requesting-code-review
```

The AI reviews its own output against the methodology. Then:

```bash
make review            # 3-layer review (methodology · artifacts · re-index)
make scan              # AgentShield security scan
git push origin feature/<name>
```

After merge:

```
/opsx:archive
```

---

## Daily command cheatsheet

| Command              | Use when                                             |
|----------------------|------------------------------------------------------|
| `make index`         | After every merge — keep the GitNexus graph fresh    |
| `make check-artifacts` | Before shipping — OpenSpec artifacts complete       |
| `make scan`          | Before every push                                    |
| `make review`        | Full 3-layer review before PR                        |
| `make update`        | Pull latest `CLAUDE.md` + `AGENTS.md` from ask-ranger |
| `make status`        | Sanity-check all tools                               |

## Platform notes

| Command group              | Claude Code | Antigravity | GitHub Copilot   |
|---------------------------|-------------|-------------|------------------|
| `/opsx:*`                  | Yes         | Yes         | Yes (via agent)  |
| `/superpowers:*`           | Yes (plugin)| Yes         | Yes (via agent)  |
| GitNexus MCP tools         | Yes         | Yes         | Partial          |

- **Claude Code**: `/plugin install superpowers@claude-plugins-official`
- **Antigravity**: skills in `.agent/skills/`, workflows in `.agent/workflows/` (auto-loaded)
- **Copilot**: agent instructions at `.github/copilot-instructions.md` + `.github/prompts/`

## Anti-patterns

| Don't                         | Do instead                              |
|-------------------------------|-----------------------------------------|
| Start coding without a spec   | `/opsx:propose` first                   |
| Skip brainstorming            | `/superpowers:brainstorming` then plan  |
| Push without review           | `make review` + `make scan`             |
| Forget to archive             | `/opsx:archive` after every merge       |
