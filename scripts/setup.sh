#!/usr/bin/env bash
# setup.sh — Install ASF into a target git repository (new or with existing code).
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
ASF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "============================================================"
echo "  ASF — Setup"
echo "  Target: $TARGET"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1. Prerequisites (node, npm, git, jq)
# ---------------------------------------------------------------------------
step "Checking prerequisites"
for cmd in node npm git; do
    command -v "$cmd" >/dev/null || fail "$cmd not found — install it first"
done
if ! command -v jq &>/dev/null; then
    info "jq missing — installing..."
    case "$(uname -s)" in
        Darwin) brew install jq >/dev/null ;;
        Linux)  sudo apt install -y jq >/dev/null ;;
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

ECC_DIR=$(mktemp -d)
if git clone --depth 1 https://github.com/affaan-m/everything-claude-code.git "$ECC_DIR" 2>/dev/null \
   && [ -f "$ECC_DIR/hooks/hooks.json" ]; then
    MERGED=$(jq -s '
        .[0] * {
            hooks: {
                PreToolUse:  (((.[0].hooks.PreToolUse // []) + (.[1].hooks.PreToolUse // [])) | unique_by(.description)),
                PostToolUse: (((.[0].hooks.PostToolUse // []) + (.[1].hooks.PostToolUse // [])) | unique_by(.description))
            }
        }
    ' "$SETTINGS" "$ECC_DIR/hooks/hooks.json" 2>/dev/null) || MERGED=""
    if [ -n "$MERGED" ]; then
        echo "$MERGED" > "$SETTINGS"
        ok "AgentShield hooks merged"
    else
        warn "Merge failed — check ~/.claude/settings.json manually"
    fi
else
    warn "Could not fetch ECC hooks — skipping"
fi
rm -rf "$ECC_DIR"

# ---------------------------------------------------------------------------
# 4. Copy ASF config to TARGET (skip if TARGET == ASF_DIR)
# ---------------------------------------------------------------------------
if [ "$TARGET" != "$ASF_DIR" ]; then
    step "Copying ASF config to target"

    # Always overwrite — system prompts must match ASF version
    for f in CLAUDE.md AGENTS.md; do
        if [ -f "$ASF_DIR/$f" ]; then
            cp "$ASF_DIR/$f" "$TARGET/$f"
            ok "$f updated"
        fi
    done

    # Skip if exists — preserve target's customizations
    for p in Makefile githooks .claude .github .agent docs; do
        if [ -e "$TARGET/$p" ]; then
            skip "$p already exists"
        elif [ -e "$ASF_DIR/$p" ]; then
            rsync -a "$ASF_DIR/$p" "$TARGET/"
            ok "$p copied"
        fi
    done

    # Merge .gitignore with marker
    MARKER="# ASF entries"
    if grep -qF "$MARKER" "$TARGET/.gitignore" 2>/dev/null; then
        skip ".gitignore already has ASF entries"
    elif [ -f "$ASF_DIR/.gitignore" ]; then
        {
            [ -f "$TARGET/.gitignore" ] && echo ""
            echo "$MARKER"
            cat "$ASF_DIR/.gitignore"
        } >> "$TARGET/.gitignore"
        ok ".gitignore updated"
    fi
else
    info "TARGET is ASF itself — skipping config copy"
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
if [ -f "$TARGET/openspec/config.yaml" ]; then
    skip "OpenSpec already initialized"
else
    (cd "$TARGET" && openspec init) && ok "OpenSpec initialized"
fi

# ---------------------------------------------------------------------------
# 7. GitNexus index
# ---------------------------------------------------------------------------
step "Indexing target with GitNexus"
if gitnexus analyze "$TARGET" 2>/dev/null; then
    ok "GitNexus index complete"
else
    warn "gitnexus analyze failed — run manually: gitnexus analyze $TARGET"
fi

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
