# Claude Code settings hardening — design

**Date:** 2026-04-14
**Scope:** `.claude/settings.json` in the vsaf project
**Triggered by:** `claude-automation-recommender` audit findings

## Problem

The project's `.claude/settings.json` has working PreToolUse/PostToolUse hooks
but is missing two things the audit flagged:

1. **MEDIUM — no permissions block.** Without explicit allow/deny lists, the
   agent relies on default permissions which may be too broad.
2. **LOW — no Stop hook.** Nothing runs at session end to verify no secrets
   leaked, no debug artifacts were left in the diff, and the knowledge graph
   index is fresh.

## Goals

- Add a permissive allowlist for the vsaf toolchain so routine work doesn't
  prompt, and a deny list to hard-block destructive patterns.
- Add a Stop hook that runs five advisory session-end checks via a single
  external shell script (keeps `settings.json` readable).
- Preserve existing PreToolUse/PostToolUse hooks unchanged.

## Non-goals

- Changing user-level `~/.claude/settings.json`.
- Replacing or duplicating the existing secret-blocking PreToolUse hook.
- Hard-failing the session end on warnings (except optional `--strict`).

## Design

### Section 1 — Permissions block

Added to `.claude/settings.json` at the top level.

**Allow list** (non-prompting):

- Core read/edit tools: `Read`, `Glob`, `Grep`, `Edit`, `Write`, `MultiEdit`,
  `TodoWrite`, `WebFetch`, `WebSearch`.
- VSAF toolchain Bash: `git:*`, `gh:*`, `make:*`, `npm:*`, `npx:*`, `node:*`,
  `gitnexus:*`, `graphify:*`, `mempalace:*`, `pytest:*`, `go:*`, `cargo:*`.
- Routine shell: `ls:*`, `cat:*`, `grep:*`, `rg:*`, `find:*`, `head:*`,
  `tail:*`.

**Deny list** (hard-blocked):

- Destructive filesystem: `Bash(rm -rf /*)`, `Bash(rm -rf ~*)`, `Bash(rm -rf *)`.
- Destructive git: `Bash(git push --force*)`, `Bash(git push -f*)`.
- Permission loosening: `Bash(chmod 777*)`.
- Secret/config file writes: `Edit(.env*)`, `Edit(*.pem)`, `Edit(*.key)`,
  `Edit(id_rsa*)`, `Edit(id_ed25519*)`, `Write(.env*)`, `Write(*.pem)`,
  `Write(*.key)`.

**Rationale:** Anything not in either list follows default behavior (prompts
the user). The deny list duplicates the existing PreToolUse protection for
defense-in-depth — the hook catches Edit/Write, the permission catches the
shell-command vector.

### Section 2 — Stop hook script `scripts/claude-stop-hook.sh`

New executable shell script (`chmod +x`). Runs five checks, prints warnings,
exits 0 by default so the turn ends cleanly. Accepts a `--strict` flag that
upgrades the secret check to a hard fail (exit 2).

**Checks:**

1. **Uncommitted secret scan** — greps `git diff HEAD` and `git diff --cached`
   against the same regex set used by the existing PreToolUse hook
   (AWS keys, GitHub PAT, OpenAI SK, Slack tokens, JWT).
2. **AgentShield reminder** — if `git diff --quiet` fails, prints a reminder
   to run `npx ecc-agentshield scan`.
3. **GitNexus staleness** — compares mtime of `.gitnexus/meta.json` against
   HEAD commit timestamp. If HEAD is newer, prints a reminder to run
   `gitnexus analyze`. Portable `stat` for macOS and Linux.
4. **Uncommitted changes summary** — prints `git status --short` indented.
5. **Debug artifact scan** — greps staged added lines
   (`git diff --cached -U0`) for `console.log`, `debugger;`, `print(`,
   `TODO:\s*remove`.

**Exit behavior:** Always exit 0 unless `--strict` is set and secrets are
found. Rationale: Stop hooks that exit non-zero block the turn end, which
is annoying for advisory warnings. Only an active secret leak is worth
hard-failing, and even that is opt-in.

**Source of truth:** The script uses `git` to determine "what changed this
session" rather than tracking Claude's tool events. Simpler and catches
changes made outside Claude too.

**Standalone use:** The script is runnable by hand
(`./scripts/claude-stop-hook.sh`) as a pre-commit sanity check.

### Section 3 — settings.json integration

Final shape of `.claude/settings.json`:

```json
{
  "permissions": { "allow": [...], "deny": [...] },
  "hooks": {
    "PreToolUse": [ /* unchanged */ ],
    "PostToolUse": [ /* unchanged */ ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/scripts/claude-stop-hook.sh\""
          }
        ]
      }
    ]
  },
  "enabledPlugins": { "superpowers@claude-plugins-official": true }
}
```

The existing PreToolUse hook on `.claude/settings.json` will block
automated edits to this file, so the update must be applied by the user
(or the hook temporarily bypassed by manual approval).

### Section 4 — Verification

- **Lint:** `jq . .claude/settings.json` — confirms valid JSON.
- **Script syntax:** `bash -n scripts/claude-stop-hook.sh`.
- **Script execution:** `./scripts/claude-stop-hook.sh` in a clean and dirty
  working tree, confirm warnings appear/disappear as expected.
- **Secret detection:** stage a fake `AKIAIOSFODNN7EXAMPLE` line, run the
  script, confirm warning fires. Unstage.
- **Stale check:** touch `.gitnexus/meta.json` to an old timestamp, confirm
  staleness warning fires.
- **End-to-end:** end a Claude session, observe `[stop-hook]` output in the
  terminal.

## Risks

- **PreToolUse block on settings.json** — by design, but means the permissions
  block must be applied with manual approval. Documented in the plan.
- **Permission pattern globs** — the exact syntax for `Bash(cmd:*)` and
  `Edit(path)` should be verified against current Claude Code docs before
  finalizing; if semantics differ, patterns may need escaping or anchoring.
- **Cross-platform `stat`** — handled via fallback, but untested on
  non-Darwin/non-GNU systems.

## Rollout

Single commit on a feature branch:

1. New file `scripts/claude-stop-hook.sh` (`chmod +x`).
2. Updated `.claude/settings.json` with permissions block and Stop hook.
3. This design doc under `docs/superpowers/specs/`.

No migration, no coordination — change is scoped to one project's Claude
configuration and one new script.
