#!/usr/bin/env bats
# Tests for scripts/setup.sh — the non-network parts.
#
# These tests stub HOME so ~/.claude/settings.json writes stay in a temp dir,
# skip npm installs for tools that are already present, and assert the
# idempotent file-copy and git-config steps behave correctly.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORK=$(mktemp -d)
    FAKE_HOME=$(mktemp -d)
    TARGET=$(mktemp -d)

    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME/.claude"
    echo '{}' > "$FAKE_HOME/.claude/settings.json"

    # Fresh git repo for the target
    git -C "$TARGET" init -q
    git -C "$TARGET" config user.email test@example.com
    git -C "$TARGET" config user.name test
}

teardown() {
    rm -rf "$WORK" "$FAKE_HOME" "$TARGET"
}

@test "setup.sh fails fast when target is not a git repo" {
    NON_GIT=$(mktemp -d)
    run bash "$ROOT/scripts/setup.sh" "$NON_GIT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Not a git repository"* ]]
    rm -rf "$NON_GIT"
}

@test "setup.sh sets core.hooksPath in target" {
    run bash "$ROOT/scripts/setup.sh" "$TARGET"
    [ "$status" -eq 0 ]

    HOOKS=$(git -C "$TARGET" config --get core.hooksPath)
    [ "$HOOKS" = "githooks/" ]
}

@test "setup.sh copies CLAUDE.md, AGENTS.md, Makefile, scripts/, workflows/, vendor/" {
    bash "$ROOT/scripts/setup.sh" "$TARGET"

    [ -f "$TARGET/CLAUDE.md" ]
    [ -f "$TARGET/AGENTS.md" ]
    [ -f "$TARGET/Makefile" ]
    [ -d "$TARGET/scripts" ]
    [ -d "$TARGET/workflows" ]
    [ -d "$TARGET/vendor/ecc-hooks" ]
    [ -x "$TARGET/githooks/pre-push" ]
}

@test "setup.sh excludes setup.sh itself from target's scripts/" {
    bash "$ROOT/scripts/setup.sh" "$TARGET"

    [ ! -f "$TARGET/scripts/setup.sh" ]
    [ -f "$TARGET/scripts/sync-platforms.sh" ]
}

@test "setup.sh substitutes {{REPO_NAME}} in CLAUDE.md with target basename" {
    bash "$ROOT/scripts/setup.sh" "$TARGET"

    NAME="$(basename "$TARGET")"
    # Token must be replaced; no raw {{REPO_NAME}} left behind.
    run grep -F "{{REPO_NAME}}" "$TARGET/CLAUDE.md"
    [ "$status" -ne 0 ]
    # Substituted value must appear in gitnexus:// URI.
    run grep -F "gitnexus://repo/$NAME/" "$TARGET/CLAUDE.md"
    [ "$status" -eq 0 ]
}

@test "setup.sh overwrites CLAUDE.md even if present" {
    echo "old content" > "$TARGET/CLAUDE.md"
    bash "$ROOT/scripts/setup.sh" "$TARGET"

    run grep -q "ask-ranger" "$TARGET/CLAUDE.md"
    [ "$status" -eq 0 ]
}

@test "setup.sh skips directories that already exist in target" {
    # Pre-populate scripts/ with sentinel content
    mkdir -p "$TARGET/scripts"
    echo "keep me" > "$TARGET/scripts/custom.sh"

    bash "$ROOT/scripts/setup.sh" "$TARGET"

    # Sentinel must survive, since we skip the dir wholesale.
    [ -f "$TARGET/scripts/custom.sh" ]
    run cat "$TARGET/scripts/custom.sh"
    [ "$output" = "keep me" ]
}

@test "setup.sh merges .gitignore only once" {
    bash "$ROOT/scripts/setup.sh" "$TARGET"
    FIRST=$(grep -c "ask-ranger entries" "$TARGET/.gitignore" || true)
    [ "$FIRST" -eq 1 ]

    bash "$ROOT/scripts/setup.sh" "$TARGET"
    SECOND=$(grep -c "ask-ranger entries" "$TARGET/.gitignore" || true)
    [ "$SECOND" -eq 1 ]
}

@test "setup.sh backs up ~/.claude/settings.json before merging" {
    bash "$ROOT/scripts/setup.sh" "$TARGET"

    # At least one backup file must exist
    run bash -c "ls $FAKE_HOME/.claude/settings.json.bak.* 2>/dev/null | wc -l"
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "setup.sh skips ECC hooks merge when ECC plugin is not installed" {
    bash "$ROOT/scripts/setup.sh" "$TARGET"

    # Without ECC plugin, hooks should NOT be merged (prevents hook errors).
    COUNT=$(jq '.hooks.PreToolUse // [] | length' "$FAKE_HOME/.claude/settings.json")
    [ "$COUNT" -eq 0 ]
}

@test "setup.sh merges ECC hooks when ECC plugin is installed" {
    # Simulate ECC plugin by creating the bootstrap file it looks for.
    mkdir -p "$FAKE_HOME/.claude/scripts/lib"
    echo "// stub" > "$FAKE_HOME/.claude/scripts/lib/utils.js"

    bash "$ROOT/scripts/setup.sh" "$TARGET"

    COUNT=$(jq '.hooks.PreToolUse | length' "$FAKE_HOME/.claude/settings.json")
    [ "$COUNT" -gt 0 ]
}

@test "setup.sh is idempotent — second run does not corrupt settings.json" {
    # Simulate ECC plugin so hooks are merged (tests idempotency of merge).
    mkdir -p "$FAKE_HOME/.claude/scripts/lib"
    echo "// stub" > "$FAKE_HOME/.claude/scripts/lib/utils.js"

    bash "$ROOT/scripts/setup.sh" "$TARGET"
    FIRST=$(jq '.hooks.PreToolUse | length' "$FAKE_HOME/.claude/settings.json")

    bash "$ROOT/scripts/setup.sh" "$TARGET"
    SECOND=$(jq '.hooks.PreToolUse | length' "$FAKE_HOME/.claude/settings.json")

    # Counts should match (dedup by description).
    [ "$FIRST" -eq "$SECOND" ]
}
