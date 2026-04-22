#!/usr/bin/env bash
# gitleaks-precheck.sh — PreToolUse hook that scans the tool input for secrets
# using gitleaks' built-in detection rules (see https://github.com/gitleaks/gitleaks).
#
# Input contract (set by Claude Code):
#   $TOOL_INPUT  — the raw tool input (file content, bash command, etc.)
#   $TOOL_INPUT_FILE (optional) — path being written, when available
#
# Exit codes:
#   0 — clean, allow
#   2 — secret detected, block tool call
#   0 — gitleaks missing (degraded mode, allow with warning to stderr)

set -u

INPUT="${TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

if ! command -v gitleaks >/dev/null 2>&1; then
    echo "[WARN] gitleaks not installed — skipping secret pre-check. Run: make setup" >&2
    exit 0
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
printf '%s' "$INPUT" > "$TMP"

# --no-banner keeps stderr quiet on clean runs.
# --no-git runs a pure filesystem scan on the temp file.
# --redact prevents secrets from being echoed back into the transcript.
if gitleaks detect --no-banner --no-git --source "$TMP" --redact --exit-code 1 >/dev/null 2>&1; then
    exit 0
fi

echo "BLOCK: gitleaks detected a secret pattern in tool input. Use environment variables or a secret manager." >&2
exit 2
