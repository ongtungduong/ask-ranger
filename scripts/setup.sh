#!/usr/bin/env bash
# setup.sh — Install ask-ranger into a target git repository (new or with existing code).
# Usage: bash scripts/setup.sh [TARGET_DIR]
#   TARGET_DIR: optional path to target repo. Defaults to current directory.
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
# Args
# ---------------------------------------------------------------------------
TARGET="${1:-$PWD}"
if ! git -C "$TARGET" rev-parse --git-dir &>/dev/null 2>&1; then
    fail "Not a git repository: $TARGET — run 'git init' first"
fi
TARGET="$(cd "$TARGET" && pwd)"
ASK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Platform support check (S5)
case "$(uname -s)" in
    Darwin|Linux) ;;
    MINGW*|MSYS*|CYGWIN*)
        warn "Windows detected — ask-ranger is tested on macOS and Linux only."
        warn "Use WSL2 for full compatibility. Continuing anyway, but some steps may fail." ;;
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
ok "node $(node -v | sed 's/v//'), npm $(npm -v), git, jq"

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
step "Merging AgentShield hooks into ~/.claude/settings.json"
mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"
[ ! -f "$SETTINGS" ] && echo '{}' > "$SETTINGS"

# Backup before mutating (S6)
BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"
info "Backed up existing settings to $BACKUP"

ECC_DIR=$(mktemp -d)
ECC_LOG=$(mktemp)
trap 'rm -rf "$ECC_DIR" "$ECC_LOG"' EXIT

if git clone --depth 1 https://github.com/affaan-m/everything-claude-code.git "$ECC_DIR" 2>"$ECC_LOG" \
   && [ -f "$ECC_DIR/hooks/hooks.json" ]; then
    MERGE_ERR=$(mktemp)
    MERGED=$(jq -s '
        .[0] * {
            hooks: {
                PreToolUse:  (((.[0].hooks.PreToolUse // []) + (.[1].hooks.PreToolUse // [])) | unique_by(.description)),
                PostToolUse: (((.[0].hooks.PostToolUse // []) + (.[1].hooks.PostToolUse // [])) | unique_by(.description))
            }
        }
    ' "$SETTINGS" "$ECC_DIR/hooks/hooks.json" 2>"$MERGE_ERR") || MERGED=""
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
    warn "Could not fetch ECC hooks — skipping. git stderr:"
    cat "$ECC_LOG" >&2
fi
rm -rf "$ECC_DIR" "$ECC_LOG"

# ---------------------------------------------------------------------------
# 4. Copy ask-ranger config to TARGET (skip if TARGET == ASK_DIR)
# ---------------------------------------------------------------------------
if [ "$TARGET" != "$ASK_DIR" ]; then
    step "Copying ask-ranger config to target"

    # Always overwrite — system prompts must match ask-ranger version
    for f in CLAUDE.md AGENTS.md; do
        if [ -f "$ASK_DIR/$f" ]; then
            cp "$ASK_DIR/$f" "$TARGET/$f"
            ok "$f updated"
        fi
    done

    # Skip if exists — preserve target's customizations
    for p in Makefile githooks scripts .claude .github .agent docs; do
        if [ -e "$TARGET/$p" ]; then
            skip "$p already exists"
        elif [ -e "$ASK_DIR/$p" ]; then
            rsync -a "$ASK_DIR/$p" "$TARGET/"
            ok "$p copied"
        fi
    done

    # Merge .gitignore with marker
    MARKER="# ask-ranger entries"
    if grep -qF "$MARKER" "$TARGET/.gitignore" 2>/dev/null; then
        skip ".gitignore already has ask-ranger entries"
    elif [ -f "$ASK_DIR/.gitignore" ]; then
        {
            [ -f "$TARGET/.gitignore" ] && echo ""
            echo "$MARKER"
            cat "$ASK_DIR/.gitignore"
        } >> "$TARGET/.gitignore"
        ok ".gitignore updated"
    fi
else
    info "TARGET is ask-ranger itself — skipping config copy"
fi

# ---------------------------------------------------------------------------
# 5. Git hooks path in target
# ---------------------------------------------------------------------------
step "Setting git hooks path in target"
git -C "$TARGET" config core.hooksPath githooks/
ok "core.hooksPath = githooks/"

# ---------------------------------------------------------------------------
# 6. OpenSpec init in target
# ---------------------------------------------------------------------------
step "Initializing OpenSpec in target"
if [ -d "$TARGET/openspec" ]; then
    skip "OpenSpec already initialized"
else
    (cd "$TARGET" && openspec init) && ok "OpenSpec initialized"
fi

# ---------------------------------------------------------------------------
# 7. GitNexus index
# ---------------------------------------------------------------------------
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
