# Rebrand VSAF → ASF (Agentic SDLC Framework)

**Date:** 2026-04-15
**Author:** brainstorming session
**Scope:** Full-repo rename of the `VSAF`/`vsaf` brand to `ASF`/`asf`, drop the `v3` version suffix, delete historical spec/plan artifacts from the pre-rebrand era, and clean-reindex GitNexus under the new name.

## Problem

The project directory is `agentic-sdlc-framework`, but the brand name `VSAF` (plus `vsaf` identifier and `VSAF v3` version tag) is baked into 148 places across 18 files: core docs, Makefile, setup script, onboarding guides, BMAD/MemPalace config, and historical spec/plan docs. The directory and the in-repo brand have drifted apart. This rebrand realigns the repo to a single consistent name — **ASF (Agentic SDLC Framework)** — and clears the legacy `v3` suffix.

## Naming Rules

| Old | New | Where it applies |
|---|---|---|
| `VSAF` | `ASF` | Brand in prose, headings, comments |
| `vsaf` | `asf` | Config values, MCP URI path segments, tmp file prefixes |
| `VSAF v3 — Agentic AI SDLC Framework` | `ASF — Agentic SDLC Framework` | Top-of-file headers |
| `VSAF v3` | `ASF` | Version tags (drop `v3` entirely) |
| `setup-vsaf.sh` | `setup-asf.sh` | Script filename |
| `cd vsaf` | `cd agentic-sdlc-framework` | Clone instructions in onboarding |
| `gitnexus://repo/vsaf/...` | `gitnexus://repo/asf/...` | MCP resource URIs (after re-index) |
| `/tmp/vsaf-*` | `/tmp/asf-*` | Temp file prefixes (irrelevant after deletion of historical docs) |
| `project_name: vsaf` | `project_name: asf` | `_bmad/bmm/config.yaml` |
| `wing: vsaf` | `wing: asf` | `mempalace.yaml` |

The repo directory name (`agentic-sdlc-framework`) stays as-is. The user will rename the GitHub repo separately after this PR merges.

## Scope

### In scope

1. **Content rewrite** — 14 non-historical files:
   - `CLAUDE.md`
   - `AGENTS.md`
   - `README.md`
   - `Makefile`
   - `.gitignore`
   - `mempalace.yaml`
   - `_bmad/bmm/config.yaml`
   - `scripts/setup-vsaf.sh` (content — file itself is renamed in step 2)
   - `docs/onboarding/1-setup-guide.md`
   - `docs/onboarding/2-workflow-guide.md`
   - `docs/onboarding/2-workflow-guide.vi.md`
   - `docs/onboarding/3-cheatsheet.md`
   - `docs/onboarding/4-milestones.md`
   - `docs/onboarding/5-faq.md`

2. **Script rename** — `git mv scripts/setup-vsaf.sh scripts/setup-asf.sh`, then update the two references inside `Makefile` and the references inside onboarding docs.

3. **Delete historical artifacts** — 4 files from the pre-rebrand era, removed entirely (rewriting them would misrepresent what actually happened in the commit history):
   - `docs/superpowers/specs/2026-04-14-claude-settings-hardening-design.md`
   - `docs/superpowers/specs/2026-04-14-fix-make-setup-warnings-design.md`
   - `docs/superpowers/plans/2026-04-14-claude-settings-hardening.md`
   - `docs/superpowers/plans/2026-04-14-fix-make-setup-warnings.md`

4. **GitNexus clean re-index** — no local `.gitnexus/` exists yet (verified: no `meta.json`), so `npx gitnexus analyze` will generate a fresh index under the new repo directory name. No embeddings to preserve.

### Out of scope

- Git history rewrite. Existing commits referencing `VSAF`/`vsaf` stay as-is.
- GitHub repo rename (`gh repo rename`). The user will do this manually.
- Git remote URL changes in local config.
- `.claude/` and `githooks/` edits — verified to contain zero `vsaf` references.

## Execution Steps

1. **Rewrite content in 14 files** using plain find-and-replace of `VSAF v3` → `ASF`, `VSAF` → `ASF`, `vsaf` → `asf`, applied carefully so that acronym replacement doesn't create double-renames (`VSAF v3` must be handled before `VSAF`). Additionally, inside onboarding guides, replace `cd vsaf` → `cd agentic-sdlc-framework`.
2. **Rename script** via `git mv scripts/setup-vsaf.sh scripts/setup-asf.sh`.
3. **Delete 4 historical artifact files** via `git rm`.
4. **GitNexus re-index** via `npx gitnexus analyze` (runs from scratch since no prior local index).
5. **Commit** everything as a single atomic commit: `chore: rebrand VSAF → ASF (Agentic SDLC Framework)`.

## Verification

```bash
# Gate 1: Zero textual references to the old brand
grep -rIn "vsaf\|VSAF\|Vsaf" . \
  --exclude-dir=.git --exclude-dir=.gitnexus --exclude-dir=node_modules \
  && echo FAIL || echo OK

# Gate 2: Script renamed
test -f scripts/setup-asf.sh && ! test -f scripts/setup-vsaf.sh && echo OK

# Gate 3: Historical artifacts deleted
for f in \
  docs/superpowers/specs/2026-04-14-claude-settings-hardening-design.md \
  docs/superpowers/specs/2026-04-14-fix-make-setup-warnings-design.md \
  docs/superpowers/plans/2026-04-14-claude-settings-hardening.md \
  docs/superpowers/plans/2026-04-14-fix-make-setup-warnings.md; do
  test ! -e "$f" || { echo "FAIL: $f still exists"; exit 1; }
done && echo OK

# Gate 4: GitNexus re-indexed under new name
npx gitnexus analyze
grep -q '"asf"' .gitnexus/meta.json && echo OK

# Gate 5: make setup still runs end-to-end
make setup 2>&1 | tail -20
```

All five gates must pass before committing.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Stale `gitnexus://repo/vsaf/...` URIs cached elsewhere | Re-index in the same commit; all in-repo doc references updated to `asf`. |
| Embedding loss on clean re-index | Pre-checked: no `.gitnexus/meta.json` exists, nothing to lose. |
| Hardcoded `vsaf` in hook scripts | Pre-checked: `.claude/` and `githooks/` contain zero matches. |
| Historical commit messages still say `VSAF` | Accepted. No git history rewrite. |
| Double-rename from acronym ordering (`VSAF v3` → `ASF v3` → `ASF`) | Process longer string first (`VSAF v3 — Agentic AI SDLC Framework` → `ASF — Agentic SDLC Framework`), then bare `VSAF` → `ASF`. |

## Commit Strategy

One atomic commit:

```
chore: rebrand VSAF → ASF (Agentic SDLC Framework)

- Rename VSAF/vsaf identifiers to ASF/asf across 14 files
- Drop v3 version suffix
- Rename scripts/setup-vsaf.sh → scripts/setup-asf.sh
- Delete 4 pre-rebrand historical spec/plan artifacts
- Clean re-index GitNexus under new name
```

Splitting the rebrand into multiple commits would create a half-rebranded intermediate state that's hard to review and hard to revert.
