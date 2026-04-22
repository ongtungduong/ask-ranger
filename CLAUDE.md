# ASF — Agentic SDLC Framework

> System prompt for Claude Code. Do not remove or override.

**Stack:** OpenSpec · GitNexus (MCP) · Claude Code + Superpowers + AgentShield  
**Platforms:** Claude Code (primary) | GitHub Copilot | Antigravity

---

## 5-Step Workflow

**Step 1 — Spec**
```
/opsx:propose <feature>
git commit -m "spec: <feature>"
```
Tasks must be atomic (2-5 min). Include edge cases.

**Step 2 — Impact Analysis**
```
gitnexus_impact({target: "symbol", direction: "upstream"})
gitnexus_context({name: "symbol"})
```
Impact > 3 modules → split PRs. Update specs if new edge cases found.

**Step 3 — Brainstorm + Plan**
```
/superpowers:brainstorm
/superpowers:write-plan
```
Do not approve until every task has a verification step.

**Step 4 — Execute**
```
/superpowers:execute-plan
```
1 commit per task. Tests after EVERY task. Fail 3× → stop, architectural review.

**Step 5 — Review + Ship**
```
/superpowers:code-review
/opsx:verify
npx ecc-agentshield scan
git push origin feature/<name>
/opsx:archive
```

---

## Anti-Patterns

| Do Not | Instead |
|---|---|
| Write code before specs | `/opsx:propose` first |
| Skip brainstorm | `/superpowers:brainstorm` before planning |
| Push without review | code-review + opsx:verify + agentshield scan |
| Create PRs > 400 lines | Split into smaller PRs |
| Trust AI output blindly | AI writes → Superpowers reviews → human approves |
| Skip impact analysis | GitNexus BEFORE coding |
| Forget to archive | `/opsx:archive` after every merge |

---

## Commit Discipline

- 1 commit per task. Message: `<type>: <description>` (feat, fix, refactor, spec, docs, test).
- Tests must pass after every commit. Fail 3× → stop, architectural review.

## Security

- AgentShield hooks active — secrets and protected files blocked automatically.
- `npx ecc-agentshield scan` after config changes. `--opus --stream` before releases.
- Never hardcode credentials. Check `.claude/settings.json` if a hook blocks unexpectedly.

---

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus. Use MCP tools to understand code, assess impact, navigate safely.

> If any tool warns the index is stale, run `gitnexus analyze` first.

## Mandatory Rules

- **MUST** run `gitnexus_impact({target: "symbolName", direction: "upstream"})` before editing any symbol. Report blast radius to user.
- **MUST** run `gitnexus_detect_changes()` before committing. Verify only expected symbols changed.
- **MUST** warn user if impact returns HIGH or CRITICAL risk before proceeding.
- Use `gitnexus_query({query: "concept"})` to explore unfamiliar code — not grep.
- Use `gitnexus_context({name: "symbolName"})` for full callers/callees view of a symbol.

## Never Do

- NEVER edit a symbol without running `gitnexus_impact` first.
- NEVER ignore HIGH or CRITICAL risk warnings.
- NEVER rename with find-and-replace — use `gitnexus_rename({..., dry_run: true})` then `false`.
- NEVER commit without `gitnexus_detect_changes()`.

## Tools

| Tool | When | Command |
|---|---|---|
| `query` | Find code by concept | `gitnexus_query({query: "..."})` |
| `context` | 360° view of a symbol | `gitnexus_context({name: "..."})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "...", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |

## Impact Risk

| Depth | Meaning | Action |
|---|---|---|
| d=1 | WILL BREAK — direct callers | MUST update |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Re-index After Commits

```bash
gitnexus analyze              # standard
gitnexus analyze --embeddings # if embeddings were previously enabled
```

> Skill files in `.claude/skills/gitnexus/` have full usage guides for exploring, debugging, refactoring, and CLI.
<!-- gitnexus:end -->
