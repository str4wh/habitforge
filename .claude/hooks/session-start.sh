#!/bin/bash
set -euo pipefail

# Only needed in Claude Code on the web (ephemeral containers).
# Local machines keep their node_modules between sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Root npm deps (firebase-admin, used by scripts/Netlify build)
npm install --prefix "$CLAUDE_PROJECT_DIR" --no-audit --no-fund

# Remotion video project deps (~560 packages)
npm install --prefix "$CLAUDE_PROJECT_DIR/remotion" --no-audit --no-fund

# Remotion needs a headless Chromium to render. The web container ships one
# for Playwright (picked up by remotion.config.ts); only download Remotion's
# own browser if that is missing (remotion.media may be blocked by policy).
if ! ls /opt/pw-browsers/chromium_headless_shell-*/chrome-linux/headless_shell >/dev/null 2>&1; then
  (cd "$CLAUDE_PROJECT_DIR/remotion" && npx remotion browser ensure)
fi
