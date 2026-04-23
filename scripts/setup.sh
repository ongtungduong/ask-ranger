#!/usr/bin/env bash
# setup.sh — Install ask-ranger into a target git repository (new or with existing code).
# Usage: bash scripts/setup.sh [--force] [TARGET_DIR]
#   --force:     overwrite existing files/directories (use to update a previous install).
#   TARGET_DIR:  optional path to target repo. Defaults to current directory.
set -euo pipefail

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
skip()  { echo -e "${YELLOW}[SKIP]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
step()  { echo -e "\n${CYAN}==> $*${NC}"; }

# ---------------------------------------------------------------------------
# Rollback / error handling
# ---------------------------------------------------------------------------
SETTINGS_BACKUP=""
STEP_REACHED="init"
CREATED_PATHS=()  # Track paths created during template copy for rollback.
on_err() {
    local ec=$?
    warn "setup failed during: $STEP_REACHED (exit $ec)"
    if [ -n "$SETTINGS_BACKUP" ] && [ -f "$SETTINGS_BACKUP" ]; then
        warn "Restoring ~/.claude/settings.json from backup: $SETTINGS_BACKUP"
        cp "$SETTINGS_BACKUP" "$HOME/.claude/settings.json" || true
    fi
    if [ ${#CREATED_PATHS[@]} -gt 0 ]; then
        warn "Rolling back ${#CREATED_PATHS[@]} created path(s)..."
        for p in "${CREATED_PATHS[@]}"; do
            if [ -e "$p" ]; then
                rm -rf "$p"
                warn "  removed $p"
            fi
        done
    fi
    warn "Rerun 'bash scripts/setup.sh \"\$TARGET\"' after fixing the issue above."
    exit "$ec"
}
trap on_err ERR

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
FORCE=false
while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        -*)      fail "Unknown option: $1" ;;
        *)       break ;;
    esac
done
TARGET="${1:-$PWD}"
if ! git -C "$TARGET" rev-parse --git-dir &>/dev/null 2>&1; then
    fail "Not a git repository: $TARGET — run 'git init' first"
fi
TARGET="$(cd "$TARGET" && pwd)"
ASK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ASK_DIR/template"
[ -d "$TEMPLATE_DIR" ] || fail "Template directory missing: $TEMPLATE_DIR — broken kit install"

REPO_NAME="$(basename "$TARGET")"

# Platform support check — hard-fail on native Windows (WSL2 reports Linux).
case "$(uname -s)" in
    Darwin|Linux) ;;
    MINGW*|MSYS*|CYGWIN*)
        fail "Native Windows is not supported. Use WSL2 (Windows Subsystem for Linux)." ;;
    *)
        warn "Unknown platform $(uname -s) — proceeding at your own risk." ;;
esac

echo ""
echo "============================================================"
echo "  ask-ranger — Setup"
echo "  Target: $TARGET"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1. Prerequisites (node, npm, git, jq)
# ---------------------------------------------------------------------------
step "Checking prerequisites"
for cmd in node npm git; do
    command -v "$cmd" >/dev/null || fail "$cmd not found — install it first"
done
NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
[ "$NODE_VER" -ge 18 ] || fail "Node.js $(node -v) found — v18+ required. Install from https://nodejs.org/"
if ! command -v jq &>/dev/null; then
    info "jq missing — installing..."
    case "$(uname -s)" in
        Darwin) brew install jq >/dev/null || fail "jq install failed — install manually: brew install jq" ;;
        Linux)  sudo apt install -y jq >/dev/null || fail "jq install failed — install manually: sudo apt install jq" ;;
        *)      fail "Install jq manually" ;;
    esac
fi

# gitleaks for secret scanning (optional but strongly recommended)
if ! command -v gitleaks &>/dev/null; then
    info "gitleaks missing — installing..."
    case "$(uname -s)" in
        Darwin) brew install gitleaks >/dev/null 2>&1 \
            || warn "gitleaks install failed — install manually: brew install gitleaks" ;;
        Linux)  sudo apt install -y gitleaks >/dev/null 2>&1 \
            || warn "gitleaks install failed via apt — install from https://github.com/gitleaks/gitleaks/releases" ;;
        *)      warn "Install gitleaks manually from https://github.com/gitleaks/gitleaks/releases" ;;
    esac
fi
GITLEAKS_VER="$(gitleaks version 2>/dev/null | head -1 || echo not-installed)"

ok "node $(node -v | sed 's/v//'), npm $(npm -v), git, jq, gitleaks($GITLEAKS_VER)"

# ---------------------------------------------------------------------------
# 2. Global tools (OpenSpec, GitNexus)
# ---------------------------------------------------------------------------
npm_install() {
    if command -v "$2" &>/dev/null; then
        ok "$2 already installed"
    else
        info "Installing $1..."
        npm install -g "$1" >/dev/null
        ok "$2 installed"
    fi
}
step "Installing global tools"
npm_install "@fission-ai/openspec@latest" openspec
npm_install "gitnexus" gitnexus

# ---------------------------------------------------------------------------
# 3. AgentShield hooks (global, in ~/.claude/settings.json)
# ---------------------------------------------------------------------------
STEP_REACHED="merge-agentshield-hooks"
step "Merging AgentShield hooks into ~/.claude/settings.json"
mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"
[ ! -f "$SETTINGS" ] && echo '{}' > "$SETTINGS"

# Backup before mutating — on_err trap will restore from this backup.
BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"
SETTINGS_BACKUP="$BACKUP"
info "Backed up existing settings to $BACKUP"

# Vendored at a pinned SHA — see template/vendor/ecc-hooks/README.md for refresh process.
VENDOR_HOOKS="$TEMPLATE_DIR/vendor/ecc-hooks/hooks.json"
if [ -f "$VENDOR_HOOKS" ]; then
    if [ -f "$ASK_DIR/vendor/ecc-hooks/SOURCE_SHA" ]; then
        info "Using vendored ECC hooks at SHA $(cat "$ASK_DIR/vendor/ecc-hooks/SOURCE_SHA")"
    fi
    MERGE_ERR=$(mktemp)
    MERGED=$(jq -s '
        .[0] * {
            hooks: (
                (.[0].hooks // {}) *
                {
                    PreToolUse:  (((.[0].hooks.PreToolUse // []) + (.[1].hooks.PreToolUse // [])) | unique_by(.description)),
                    PostToolUse: (((.[0].hooks.PostToolUse // []) + (.[1].hooks.PostToolUse // [])) | unique_by(.description))
                }
            )
        }
    ' "$SETTINGS" "$VENDOR_HOOKS" 2>"$MERGE_ERR") || MERGED=""
    if [ -n "$MERGED" ]; then
        echo "$MERGED" > "$SETTINGS"
        ok "AgentShield hooks merged (restore with: cp $BACKUP $SETTINGS)"
    else
        warn "Merge failed — check ~/.claude/settings.json manually. jq stderr:"
        cat "$MERGE_ERR" >&2
        warn "Original settings preserved at $BACKUP"
    fi
    rm -f "$MERGE_ERR"
else
    warn "Vendored hooks not found at $VENDOR_HOOKS — skipping AgentShield setup"
fi

# ---------------------------------------------------------------------------
# 4. Copy ask-ranger config to TARGET (skip if TARGET == ASK_DIR)
# ---------------------------------------------------------------------------
STEP_REACHED="copy-template"
if [ "$TARGET" != "$ASK_DIR" ]; then
    step "Copying ask-ranger config to target"

    # 4a. Always overwrite CLAUDE.md + AGENTS.md with token substitution
    # {{REPO_NAME}} → basename of target repo (used in gitnexus:// URIs).
    for f in CLAUDE.md AGENTS.md; do
        if [ -f "$TEMPLATE_DIR/$f" ]; then
            [ ! -f "$TARGET/$f" ] && CREATED_PATHS+=("$TARGET/$f")
            sed "s|{{REPO_NAME}}|$REPO_NAME|g" "$TEMPLATE_DIR/$f" > "$TARGET/$f"
            ok "$f updated (REPO_NAME=$REPO_NAME)"
        fi
    done

    # 4b. Copy directories that exist in template/ — skip if target already has them.
    #     --force overwrites existing paths.
    for p in Makefile githooks workflows vendor .claude .github .agent docs; do
        if [ -e "$TARGET/$p" ] && [ "$FORCE" = false ]; then
            skip "$p already exists (use --force to overwrite)"
        elif [ -e "$TEMPLATE_DIR/$p" ]; then
            [ ! -e "$TARGET/$p" ] && CREATED_PATHS+=("$TARGET/$p")
            rsync -a "$TEMPLATE_DIR/$p" "$TARGET/"
            ok "$p copied"
        fi
    done

    # 4c. Copy scripts/ (user-facing tools only — exclude kit-only setup.sh).
    if [ -e "$TARGET/scripts" ] && [ "$FORCE" = false ]; then
        skip "scripts/ already exists (use --force to overwrite)"
    else
        [ ! -e "$TARGET/scripts" ] && CREATED_PATHS+=("$TARGET/scripts")
        rsync -a --exclude 'setup.sh' "$ASK_DIR/scripts/" "$TARGET/scripts/"
        ok "scripts/ copied (setup.sh excluded — kit-only)"
    fi

    # 4d. Merge .gitignore with marker — source is template/.gitignore.append
    MARKER="# ask-ranger entries"
    if grep -qF "$MARKER" "$TARGET/.gitignore" 2>/dev/null; then
        skip ".gitignore already has ask-ranger entries"
    elif [ -f "$TEMPLATE_DIR/.gitignore.append" ]; then
        {
            [ -f "$TARGET/.gitignore" ] && echo ""
            echo "$MARKER"
            cat "$TEMPLATE_DIR/.gitignore.append"
        } >> "$TARGET/.gitignore"
        ok ".gitignore updated"
    fi
else
    info "TARGET is ask-ranger itself — skipping config copy"
fi

# ---------------------------------------------------------------------------
# 5. Git hooks path in target — guard against clobbering existing hooks
# ---------------------------------------------------------------------------
STEP_REACHED="set-hooks-path"
step "Setting git hooks path in target"
CUR_HOOKS="$(git -C "$TARGET" config --get core.hooksPath 2>/dev/null || true)"
if [ -n "$CUR_HOOKS" ] && [ "$CUR_HOOKS" != "githooks/" ] && [ "$CUR_HOOKS" != "githooks" ]; then
    warn "core.hooksPath already set to '$CUR_HOOKS' — NOT overriding."
    warn "If you want ask-ranger's pre-push hook, set it manually: git config core.hooksPath githooks/"
else
    git -C "$TARGET" config core.hooksPath githooks/
    ok "core.hooksPath = githooks/"
fi

# ---------------------------------------------------------------------------
# 6. OpenSpec init in target
# ---------------------------------------------------------------------------
STEP_REACHED="openspec-init"
step "Initializing OpenSpec in target"
if [ -d "$TARGET/openspec" ]; then
    skip "OpenSpec already initialized"
else
    (cd "$TARGET" && openspec init) && ok "OpenSpec initialized"
fi

# ---------------------------------------------------------------------------
# 7. GitNexus index
# ---------------------------------------------------------------------------
STEP_REACHED="gitnexus-index"
step "Indexing target with GitNexus"
GITNEXUS_LOG=$(mktemp)
if gitnexus analyze "$TARGET" 2>"$GITNEXUS_LOG"; then
    ok "GitNexus index complete"
else
    warn "gitnexus analyze failed — run manually: gitnexus analyze $TARGET"
    warn "stderr:"
    cat "$GITNEXUS_LOG" >&2
fi
rm -f "$GITNEXUS_LOG"

# ---------------------------------------------------------------------------
# 8. Final instructions
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Setup complete."
echo ""
echo "  Manual step in Claude Code:"
echo "    /plugin install superpowers@claude-plugins-official"
echo ""
echo "  Then restart Claude Code."
echo "============================================================"
echo ""
