#!/usr/bin/env bash
# gitleaks-precheck.sh — PreToolUse hook that scans tool input for secrets
# using gitleaks' built-in detection rules (see https://github.com/gitleaks/gitleaks).
#
# Input contract (Claude Code PreToolUse hook protocol):
#   JSON payload on stdin, with fields:
#     .tool_name           — name of the tool being invoked
#     .tool_input.command  — for Bash
#     .tool_input.content  — for Write
#     .tool_input.new_string — for Edit (single replacement)
#     .tool_input.edits[].new_string — for MultiEdit
#     .tool_input.file_path — path being edited/written (informational)
#
# Backwards-compat: if TOOL_INPUT env var is set and stdin is empty, use it.
# This lets older harnesses keep working.
#
# Exit codes:
#   0 — clean, allow tool call
#   2 — secret detected OR gitleaks missing, block tool call (fail-close)

set -u

# --- Read payload ---------------------------------------------------------
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD=$(cat 2>/dev/null || true)
fi

# --- Extract the content to scan -----------------------------------------
INPUT=""
if [ -n "$PAYLOAD" ] && command -v jq >/dev/null 2>&1; then
    # Try structured extraction. Concatenate every candidate field so one payload
    # scan covers Bash commands, Write content, Edit/MultiEdit replacements.
    INPUT=$(
        printf '%s' "$PAYLOAD" | jq -r '
            [
                .tool_input.command // empty,
                .tool_input.content // empty,
                .tool_input.new_string // empty,
                (.tool_input.edits // [] | map(.new_string // empty) | join("\n"))
            ]
            | map(select(. != ""))
            | join("\n")
        ' 2>/dev/null || true
    )
fi

# Backwards-compat path: fall back to TOOL_INPUT env var if stdin yielded nothing.
if [ -z "$INPUT" ] && [ -n "${TOOL_INPUT:-}" ]; then
    INPUT="$TOOL_INPUT"
fi

# Nothing to scan (e.g., Read tool) — allow.
[ -z "$INPUT" ] && exit 0

# --- gitleaks availability (fail-close) ----------------------------------
if ! command -v gitleaks >/dev/null 2>&1; then
    echo "BLOCK: gitleaks not installed — required for secret pre-check." >&2
    echo "       Install: brew install gitleaks  (macOS)" >&2
    echo "                sudo apt install gitleaks  (Linux)" >&2
    echo "                https://github.com/gitleaks/gitleaks/releases" >&2
    echo "       Or run: make setup" >&2
    exit 2
fi

# --- Scan ----------------------------------------------------------------
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
printf '%s' "$INPUT" > "$TMP"

# --no-banner keeps stderr quiet on clean runs.
# --no-git runs a pure filesystem scan.
# --redact prevents secrets from leaking back into the transcript.
if gitleaks detect --no-banner --no-git --source "$TMP" --redact --exit-code 1 >/dev/null 2>&1; then
    exit 0
fi

echo "BLOCK: gitleaks detected a secret pattern in tool input." >&2
echo "       Use environment variables or a secret manager instead of inlining." >&2
exit 2
