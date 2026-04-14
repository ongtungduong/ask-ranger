#!/usr/bin/env bash
# setup-vsaf.sh — VSAF - SDLC Agentic Framework setup
# Installs and configures: BMAD, OpenSpec, ECC (cherry-pick), GitNexus,
# Graphify, claude-mem, MemPalace, Superpowers (manual step).
# Idempotent. Ubuntu 24 / macOS supported.
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[FAIL]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
step()  { echo -e "\n${CYAN}==> $*${NC}"; }

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}

# ---------------------------------------------------------------------------
# Auto-install missing prerequisites (pipx, jq)
# ---------------------------------------------------------------------------
auto_install_prereqs() {
    step "Auto-installing missing prerequisites"
    local OS
    OS=$(detect_os)
    local installed_any=0

    # pipx
    if ! command -v pipx &>/dev/null; then
        info "pipx not found — attempting auto-install..."
        case "$OS" in
            linux)
                sudo apt install -y pipx &>/dev/null && pipx ensurepath &>/dev/null \
                    && ok "pipx auto-installed (apt)" && installed_any=1 \
                    || err "Failed to auto-install pipx. Install manually: sudo apt install pipx && pipx ensurepath"
                ;;
            macos)
                brew install pipx &>/dev/null && pipx ensurepath &>/dev/null \
                    && ok "pipx auto-installed (brew)" && installed_any=1 \
                    || err "Failed to auto-install pipx. Install manually: brew install pipx && pipx ensurepath"
                ;;
            *)
                err "Unknown OS — install pipx manually: https://pypa.github.io/pipx/"
                ;;
        esac
        # Refresh PATH so pipx is available in this session
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # jq
    if ! command -v jq &>/dev/null; then
        info "jq not found — attempting auto-install..."
        case "$OS" in
            linux)
                sudo apt install -y jq &>/dev/null \
                    && ok "jq auto-installed (apt)" && installed_any=1 \
                    || err "Failed to auto-install jq. Install manually: sudo apt install jq"
                ;;
            macos)
                brew install jq &>/dev/null \
                    && ok "jq auto-installed (brew)" && installed_any=1 \
                    || err "Failed to auto-install jq. Install manually: brew install jq"
                ;;
            *)
                err "Unknown OS — install jq manually: https://jqlang.github.io/jq/"
                ;;
        esac
    fi

    if [ "$installed_any" -eq 0 ]; then
        ok "No auto-install needed — all installable prerequisites present"
    fi
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prereqs() {
    step "Checking prerequisites"
    local failed=0

    # Node >= 18
    if command -v node &>/dev/null; then
        NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
        if [ "$NODE_VER" -ge 18 ]; then
            ok "Node.js v$(node -v | sed 's/v//')"
        else
            err "Node.js $(node -v) found — v18+ required. Install: https://nodejs.org/"
            failed=1
        fi
    else
        err "Node.js not found — v18+ required. Install: https://nodejs.org/"
        failed=1
    fi

    # npm
    if command -v npm &>/dev/null; then
        ok "npm $(npm -v)"
    else
        err "npm not found — install Node.js (includes npm): https://nodejs.org/"
        failed=1
    fi

    # Python >= 3.10
    if command -v python3 &>/dev/null; then
        PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.minor}")')
        PY_MAJ=$(python3 -c 'import sys; print(f"{sys.version_info.major}")')
        if [ "$PY_MAJ" -ge 3 ] && [ "$PY_VER" -ge 10 ]; then
            ok "Python $(python3 --version | awk '{print $2}')"
        else
            err "Python $(python3 --version) — 3.10+ required. Install: https://www.python.org/downloads/"
            failed=1
        fi
    else
        err "python3 not found — 3.10+ required. Install: https://www.python.org/downloads/"
        failed=1
    fi

    # pip3
    if command -v pip3 &>/dev/null; then
        ok "pip3 $(pip3 --version | awk '{print $2}')"
    else
        err "pip3 not found — install: sudo apt install python3-pip (Ubuntu) or comes with Python (macOS)"
        failed=1
    fi

    # pipx
    if command -v pipx &>/dev/null; then
        ok "pipx $(pipx --version 2>&1)"
    else
        err "pipx not found — required for Python tool isolation (PEP 668). Install: sudo apt install pipx && pipx ensurepath"
        failed=1
    fi

    # git
    if command -v git &>/dev/null; then
        ok "git $(git --version | awk '{print $3}')"
    else
        err "git not found — install: sudo apt install git (Ubuntu) or xcode-select --install (macOS)"
        failed=1
    fi

    # jq
    if command -v jq &>/dev/null; then
        ok "jq $(jq --version 2>&1 | sed 's/jq-//')"
    else
        err "jq not found — required for ECC hook merging. Install: sudo apt install jq (Ubuntu) or brew install jq (macOS)"
        failed=1
    fi

    if [ "$failed" -ne 0 ]; then
        fail "Missing prerequisites. Install them and re-run."
    fi
    ok "All prerequisites satisfied"
}

# ---------------------------------------------------------------------------
# Tool installation helpers
# ---------------------------------------------------------------------------
npm_global_install() {
    local pkg="$1"
    local cmd="${2:-$pkg}"
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd already installed"
    else
        info "Installing $pkg..."
        npm install -g "$pkg"
        ok "$cmd installed"
    fi
}

pipx_install() {
    local pkg="$1"
    if pipx list 2>/dev/null | grep -q "$pkg"; then
        ok "$pkg already installed (pipx)"
    else
        info "Installing $pkg via pipx..."
        pipx install "$pkg"
        ok "$pkg installed"
    fi
}

# ---------------------------------------------------------------------------
# 1. BMAD Method
# ---------------------------------------------------------------------------
install_bmad() {
    step "Installing BMAD Method"
    if [ -d ".bmad" ] || [ -f ".bmad-method.json" ]; then
        ok "BMAD already initialized in project"
    else
        npx bmad-method install
        ok "BMAD Method installed"
    fi
}

# ---------------------------------------------------------------------------
# 2. OpenSpec
# ---------------------------------------------------------------------------
install_openspec() {
    step "Installing OpenSpec"
    npm_global_install "@fission-ai/openspec@latest" "openspec"
    if [ -f "openspec/config.json" ] || [ -f "openspec.json" ]; then
        ok "OpenSpec already initialized"
    else
        openspec init
        ok "OpenSpec initialized"
    fi
}

# ---------------------------------------------------------------------------
# 3. ECC Cherry-Pick (AgentShield + hooks + language skills)
# ---------------------------------------------------------------------------
install_ecc_cherrypick() {
    step "ECC Cherry-Pick: AgentShield + hooks + language skills"

    local ECC_DIR="/tmp/ecc"
    local CLAUDE_HOME="${HOME}/.claude"

    # Clone if not present
    if [ ! -d "$ECC_DIR" ]; then
        info "Cloning ECC repository..."
        git clone --depth 1 https://github.com/anthropics/ecc.git "$ECC_DIR" 2>/dev/null \
            || git clone --depth 1 https://github.com/affaan-m/everything-claude-code.git "$ECC_DIR"
    fi

    # -- Merge hooks into ~/.claude/settings.json --
    mkdir -p "$CLAUDE_HOME"
    local TARGET="$CLAUDE_HOME/settings.json"
    [ ! -f "$TARGET" ] && echo '{}' > "$TARGET"
    if [ -f "$ECC_DIR/hooks/hooks.json" ]; then
        if [ -f "$TARGET" ]; then
            info "Merging ECC hooks into $TARGET (non-destructive)..."
            local MERGED
            MERGED=$(jq -s '
                .[0] as $existing |
                .[1] as $ecc |
                $existing * {
                    hooks: {
                        PreToolUse:  (($existing.hooks.PreToolUse // []) + ($ecc.hooks.PreToolUse // []) | unique_by(.description)),
                        PostToolUse: (($existing.hooks.PostToolUse // []) + ($ecc.hooks.PostToolUse // []) | unique_by(.description))
                    }
                }
            ' "$TARGET" "$ECC_DIR/hooks/hooks.json" 2>/dev/null) || true
            if [ -n "$MERGED" ]; then
                echo "$MERGED" > "$TARGET"
                ok "Hooks merged into $TARGET"
            else
                warn "Could not merge hooks — manual merge may be needed"
            fi
        else
            cp "$ECC_DIR/hooks/hooks.json" "$TARGET"
            ok "Hooks copied to $TARGET"
        fi
    else
        warn "ECC hooks/hooks.json not found — skipping hook merge"
    fi

    # -- Copy language skills --
    # Skills live at the top level of ECC's skills/ dir. Directory names match
    # each skill's `name:` frontmatter so Claude resolves them consistently.
    mkdir -p "$CLAUDE_HOME/skills"
    local ECC_SKILLS=(
        "golang-patterns"
        "rust-patterns"
        "python-patterns"
        "java-coding-standards"
        "nestjs-patterns"
        "nextjs-turbopack"
    )
    for skill in "${ECC_SKILLS[@]}"; do
        local SRC="$ECC_DIR/skills/$skill"
        local DST="$CLAUDE_HOME/skills/$skill"
        if [ -d "$SRC" ]; then
            if [ -d "$DST" ]; then
                ok "Skill: $skill already installed"
            else
                cp -r "$SRC" "$DST"
                ok "Skill: $skill installed"
            fi
        else
            warn "Skill source not found: $SRC"
        fi
    done

    # -- Cleanup --
    rm -rf "$ECC_DIR"
    ok "ECC cherry-pick complete (temp clone removed)"
}

# ---------------------------------------------------------------------------
# 4. GitNexus
# ---------------------------------------------------------------------------
install_gitnexus() {
    step "Installing GitNexus"
    npm_global_install "gitnexus" "gitnexus"
    info "Running gitnexus setup..."
    gitnexus setup 2>/dev/null || true
    info "Indexing repository..."
    gitnexus analyze . 2>/dev/null || warn "gitnexus analyze failed — run manually after setup"
    gitnexus analyze --skills 2>/dev/null || true
    ok "GitNexus configured"
}

# ---------------------------------------------------------------------------
# 5. Graphify
# ---------------------------------------------------------------------------
install_graphify() {
    step "Installing Graphify"
    pipx_install "graphifyy"
    if command -v graphify &>/dev/null; then
        graphify install 2>/dev/null || true
        ok "Graphify installed (run '/graphify .' inside Claude Code to build graph)"
    else
        warn "graphify command not found in PATH after pipx install"
    fi
}

# ---------------------------------------------------------------------------
# 6. claude-mem (auto-pilot memory)
# ---------------------------------------------------------------------------
install_claude_mem() {
    step "Installing claude-mem"
    info "Running npx claude-mem install..."
    npx claude-mem install 2>/dev/null || warn "claude-mem install had issues — check manually"
    ok "claude-mem installed (5 hooks auto-registered, web viewer: http://localhost:37777)"
}

# ---------------------------------------------------------------------------
# 7. MemPalace (knowledge base)
# ---------------------------------------------------------------------------
install_mempalace() {
    step "Installing MemPalace"
    pipx_install "mempalace"

    local PROJECT_DIR
    PROJECT_DIR="$(pwd)"

    if command -v mempalace &>/dev/null; then
        mempalace init "$PROJECT_DIR" 2>/dev/null || ok "MemPalace already initialized"
        if claude mcp list 2>/dev/null | grep -q '^mempalace:'; then
            ok "MemPalace MCP server already registered"
        else
            info "Registering MemPalace MCP server..."
            local MEMPALACE_PYTHON
            MEMPALACE_PYTHON="$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)/mempalace/bin/python"
            if [ -x "$MEMPALACE_PYTHON" ]; then
                claude mcp add mempalace -- "$MEMPALACE_PYTHON" -m mempalace.mcp_server 2>/dev/null \
                    || warn "Could not auto-register MCP server — run manually: claude mcp add mempalace -- python -m mempalace.mcp_server"
            else
                claude mcp add mempalace -- python -m mempalace.mcp_server 2>/dev/null \
                    || warn "Could not auto-register MCP server — run manually: claude mcp add mempalace -- python -m mempalace.mcp_server"
            fi
        fi
        ok "MemPalace configured"
    else
        warn "mempalace command not found in PATH after pipx install"
    fi
}

# ---------------------------------------------------------------------------
# 8. Superpowers (manual — requires Claude Code interactive session)
# ---------------------------------------------------------------------------
print_superpowers_instructions() {
    step "Superpowers (manual step)"
    echo ""
    echo "  Superpowers requires an interactive Claude Code session."
    echo "  Run this command inside Claude Code:"
    echo ""
    echo "    /plugin install superpowers@claude-plugins-official"
    echo ""
    echo "  Then restart Claude Code."
    echo ""
    warn "Superpowers cannot be automated — complete manually after this script"
}

# ---------------------------------------------------------------------------
# Git hooks configuration
# ---------------------------------------------------------------------------
configure_git_hooks() {
    step "Configuring git hooks"
    mkdir -p githooks
    git config core.hooksPath githooks/
    ok "Git hooks path set to githooks/"
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
verify_install() {
    step "Verifying installation"
    local pass=0
    local total=0

    verify_cmd() {
        total=$((total + 1))
        if eval "$1" &>/dev/null; then
            ok "$2"
            pass=$((pass + 1))
        else
            warn "$2 — FAILED"
        fi
    }

    verify_cmd "gitnexus status"                    "GitNexus indexed"
    verify_cmd "ls graphify-out/ 2>/dev/null"       "Graphify output directory exists"
    verify_cmd "command -v mempalace"               "MemPalace binary available"
    verify_cmd "command -v openspec"                "OpenSpec binary available"
    verify_cmd "npx ecc-agentshield --version"      "AgentShield available"
    verify_cmd "test -f ${HOME}/.claude/settings.json" "Global Claude hooks configured"
    verify_cmd "test -f .claude/settings.json"      "Local Claude hooks configured"

    echo ""
    info "Verification: $pass/$total checks passed"
    if [ "$pass" -lt "$total" ]; then
        warn "Some tools need manual attention. See warnings above."
    else
        ok "All verifications passed"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo "============================================================"
    echo "  VSAF — SDLC Agentic Framework Setup"
    echo "  Spec-driven development | 3-layer review | 8 tools"
    echo "============================================================"
    echo ""

    auto_install_prereqs
    check_prereqs

    install_bmad
    install_openspec
    install_ecc_cherrypick
    install_gitnexus
    install_graphify
    install_claude_mem
    install_mempalace
    print_superpowers_instructions
    configure_git_hooks

    verify_install

    echo ""
    echo "============================================================"
    echo "  Setup complete. Next steps:"
    echo "  1. Install Superpowers in Claude Code (see instructions above)"
    echo "  2. Run:  make index    (build knowledge graph)"
    echo "  3. Run:  make status   (verify all tools)"
    echo "  4. Read: CLAUDE.md     (system prompt / workflow rules)"
    echo "============================================================"
    echo ""
}

main "$@"
