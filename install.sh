#!/usr/bin/env bash
# Claude Code config - macOS/Linux installer
# Idempotent: backs up every file it changes first.
set -euo pipefail
# Claude Code is not installed or pinned here: it updates itself, and it
# must already be logged in with your subscription. Last verified on
# Claude Code 2.1.322 (2026-11-12).
# MCP servers the config launches by name (see install.ps1)
PKGS=("firecrawl-mcp@3.36.1" "@playwright/mcp@0.0.84")
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [ "${1:-}" = "--latest" ]; then
  PKGS=("firecrawl-mcp@latest" "@playwright/mcp@latest")
fi

echo "== Claude Code config installer =="
for tool in node npm claude; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool required but not on PATH"; exit 1; }
done
# firecrawl-mcp declares engines node >=22.0.0
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "ERROR: Node.js 22 or newer is required (found $(node --version)): the Firecrawl MCP server needs it"
  exit 1
fi
echo "claude version: $(claude --version)"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "WARN: ANTHROPIC_API_KEY is set. Claude Code uses an approved API key before your"
  echo "  subscription login, and bills the key. Unset it, then check /status in claude."
fi

echo "Installing ${PKGS[*]} ..."
npm install -g "${PKGS[@]}"
# the Playwright MCP drives Google Chrome (--browser chrome); these are the
# paths Playwright itself checks. Installing Chrome is left to the user.
case "$(uname -s)" in
  Darwin) CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ;;
  *) CHROME="/opt/google/chrome/chrome" ;;
esac
if [ -x "$CHROME" ]; then
  echo "Google Chrome found for the Playwright MCP: $CHROME"
else
  echo "WARN: Google Chrome not found at $CHROME. The browser tools (Playwright MCP) need it:"
  echo "  install it from https://www.google.com/chrome/ or run: npx playwright install chrome (needs admin rights)"
fi

# settings, instructions, hook, agents and skills (scripts/install-config.cjs)
node "$REPO_ROOT/scripts/install-config.cjs" "$STAMP"

# MCP servers, user scope (~/.claude.json). Removed first so a re-install
# replaces them. ${FIRECRAWL_API_KEY} stays literal here: Claude Code
# expands it when it starts the server, so the key is never stored.
claude mcp remove --scope user firecrawl >/dev/null 2>&1 || true
claude mcp remove --scope user playwright >/dev/null 2>&1 || true
# shellcheck disable=SC2016
claude mcp add --scope user --env 'FIRECRAWL_API_KEY=${FIRECRAWL_API_KEY}' --transport stdio firecrawl -- firecrawl-mcp
claude mcp add --scope user --transport stdio playwright -- playwright-mcp --browser chrome

# kopipasta - the context oracle behind the codebase-map skill (best effort)
if command -v uv >/dev/null 2>&1; then
  uv tool install --force kopipasta || echo "WARN: kopipasta install failed"
elif command -v pip3 >/dev/null 2>&1; then
  pip3 install --upgrade kopipasta || echo "WARN: kopipasta install failed"
else
  echo "WARN: neither uv nor pip3 found - skipping kopipasta. The codebase-map skill needs it: uv tool install kopipasta"
fi

# herdr TUI (optional) - wired only when already on PATH, never downloaded
# here (see install.ps1)
if command -v herdr >/dev/null 2>&1; then
  HERDR_CFG="$HOME/.config/herdr/config.toml"
  mkdir -p "$(dirname "$HERDR_CFG")"
  if [ -f "$HERDR_CFG" ]; then
    echo "Backing up $HERDR_CFG -> $HERDR_CFG.bak-$STAMP"
    cp "$HERDR_CFG" "$HERDR_CFG.bak-$STAMP"
  fi
  cp "$REPO_ROOT/config/herdr/config.toml" "$HERDR_CFG"
  # the config's Claude keys load claude.cjs from beside it
  cp "$REPO_ROOT/config/herdr/claude.cjs" "$(dirname "$HERDR_CFG")/claude.cjs"
  echo "Herdr config installed to $HERDR_CFG"
  echo "  (herdr already running? apply it with: herdr server reload-config)"
  herdr integration install claude || echo "WARN: herdr integration install claude failed - retry it by hand"
  herdr integration status || true
else
  echo "Herdr not found - skipped (optional). To add it, install it, then re-run this installer:"
  echo "  curl -fsSL https://herdr.dev/install.sh | sh"
fi

echo ""
echo "== Login and keys =="
echo "  Models run on your Claude subscription: run claude and /login if you have not."
echo '  export FIRECRAWL_API_KEY="<optional-firecrawl-key>"'
echo '  export GEMINI_API_KEY="<optional-key-for-kopipasta-ask>"'
echo "  (no Firecrawl key? run: claude mcp remove --scope user firecrawl)"

echo ""
echo "== Agent roster =="
ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents"
echo ""
echo "== MCP servers =="
claude mcp list | grep -E '^(firecrawl|playwright)' || true
echo ""
echo "Done. Expected agents: quick, boss, coder."
echo "      Expected MCP servers: firecrawl and playwright, both connected."
echo "Try:  claude --agent quick   (claude --agent boss for the hard work)"
