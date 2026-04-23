#!/usr/bin/env bash
# Session-end verification hook for Claude Code.
# Scans staged files for secrets (via gitleaks) and debug artifacts.
set -u

cd "${PROJECT_DIR:-.}" 2>/dev/null || exit 0

ISSUES=""

# 1. Secret scan on staged changes via gitleaks.
if command -v gitleaks >/dev/null 2>&1; then
    GL_OUT=$(gitleaks detect --no-banner --staged --redact 2>&1) || {
        # Non-zero means gitleaks found something or errored.
        if echo "$GL_OUT" | grep -q "leaks found"; then
            ISSUES="${ISSUES}WARNING: gitleaks detected staged secrets. Review with: gitleaks detect --staged --redact. "
        fi
    }
else
    ISSUES="${ISSUES}INFO: gitleaks not installed — skipping secret scan. Install: make setup. "
fi

# 2. Debug artifacts in staged files (console.log, debugger).
LOGS=$(git diff --cached --diff-filter=ACM --name-only -z 2>/dev/null \
  | grep -zvE '\.(md|txt|lock|json)$' \
  | xargs -0 -I{} grep -lE 'console[.]log|^[[:space:]]*debugger[[:space:]]*;?$' "{}" 2>/dev/null) || true

if [ -n "$LOGS" ]; then
    ISSUES="${ISSUES}WARNING: Debug artifacts in staged files: ${LOGS} "
fi

if [ -n "$ISSUES" ]; then
    echo "$ISSUES"
fi
