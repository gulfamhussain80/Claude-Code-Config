# Claude Code config - Windows installer
# PowerShell 5.1 compatible. Idempotent: backs up every file it changes first.
param(
    [switch]$Latest  # install the newest MCP servers instead of the tested pins
)
$ErrorActionPreference = 'Stop'
# Claude Code is not installed or pinned here: it updates itself, and it
# must already be logged in with your subscription. Last verified on
# Claude Code 2.1.322 (2026-11-12, macOS).
# MCP servers the config launches by name.
$pkgs = @('firecrawl-mcp@3.36.1', '@playwright/mcp@0.0.84')
if ($Latest) { $pkgs = @('firecrawl-mcp@latest', '@playwright/mcp@latest') }
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "== Claude Code config installer ==" -ForegroundColor Cyan

# 1. Prerequisites
foreach ($tool in @('node', 'npm', 'claude')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required but not on PATH. Install it and re-run."
    }
}
# firecrawl-mcp declares engines node >=22.0.0.
$nodeVersion = (node --version).Trim()
if ([int]($nodeVersion.TrimStart('v').Split('.')[0]) -lt 22) {
    throw "Node.js 22 or newer is required (found $nodeVersion): the Firecrawl MCP server needs it."
}
Write-Host ("claude version: " + (claude --version))
if ($env:ANTHROPIC_API_KEY) {
    Write-Warning "ANTHROPIC_API_KEY is set. Claude Code uses an approved API key before your subscription login, and bills the key. Remove it, then check /status in claude."
}

# 2. The MCP servers the config launches by name.
Write-Host "Installing $($pkgs -join ', ') ..."
npm install -g @pkgs   # splatted: one argument per package for npm.ps1 and npm.cmd alike
if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
# The Playwright MCP drives Google Chrome (--browser chrome). These are the
# prefixes Playwright itself searches on Windows. Installing Chrome is left
# to the user: Playwright's own Chrome installer is a machine-wide MSI.
$chrome = @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)}) |
    Where-Object { $_ } |
    ForEach-Object { Join-Path $_ 'Google\Chrome\Application\chrome.exe' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
if ($chrome) {
    Write-Host "Google Chrome found for the Playwright MCP: $chrome"
}
else {
    Write-Warning "Google Chrome not found. The browser tools (Playwright MCP) need it: install it from https://www.google.com/chrome/ or run 'npx playwright install chrome' in an Administrator terminal."
}

# 3. Settings, instructions, hook, agents and skills
# (scripts/install-config.cjs, shared with install.sh).
node (Join-Path $repoRoot 'scripts\install-config.cjs') $stamp
if ($LASTEXITCODE -ne 0) { throw "config install failed (exit $LASTEXITCODE)" }

# 4. MCP servers, user scope (~/.claude.json). Removed first so a
# re-install replaces them; cmd /c swallows the "not found" of a first
# install, which PowerShell 5.1 would turn into a terminating error.
# ${FIRECRAWL_API_KEY} stays literal: Claude Code expands it when it starts
# the server, so the key is never stored.
cmd /c "claude mcp remove --scope user firecrawl >nul 2>&1"
cmd /c "claude mcp remove --scope user playwright >nul 2>&1"
claude mcp add --scope user --env 'FIRECRAWL_API_KEY=${FIRECRAWL_API_KEY}' --transport stdio firecrawl '--' firecrawl-mcp
if ($LASTEXITCODE -ne 0) { Write-Warning "claude mcp add firecrawl failed (exit $LASTEXITCODE)" }
claude mcp add --scope user --transport stdio playwright '--' playwright-mcp --browser chrome
if ($LASTEXITCODE -ne 0) { Write-Warning "claude mcp add playwright failed (exit $LASTEXITCODE)" }

# 5. kopipasta - the context oracle behind the codebase-map skill.
# Best-effort: no Python toolchain must never fail the install.
$kopiOk = $false
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host "Installing kopipasta (uv) ..."
    uv tool install --force kopipasta
    $kopiOk = ($LASTEXITCODE -eq 0)
}
elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    Write-Host "Installing kopipasta (pip) ..."
    pip install --upgrade kopipasta
    $kopiOk = ($LASTEXITCODE -eq 0)
}
if ($kopiOk) {
    # 0.70.0 introduced the verbs; older builds have no `map`.
    Write-Host "kopipasta installed. Verify with: kopipasta map --help"
}
else {
    Write-Warning "kopipasta not installed (needs uv or pip). The codebase-map skill falls back to plain reads until you run: uv tool install kopipasta"
}

# 6. Herdr TUI (optional, README "Herdr"). Wired only when herdr is already
# on PATH - this installer never downloads it.
if (Get-Command herdr -ErrorAction SilentlyContinue) {
    $herdrDir = Join-Path $env:APPDATA 'herdr'
    $herdrCfg = Join-Path $herdrDir 'config.toml'
    if (Test-Path $herdrCfg) {
        Write-Host "Backing up $herdrCfg -> $herdrCfg.bak-$stamp"
        Copy-Item $herdrCfg "$herdrCfg.bak-$stamp" -Force
    }
    New-Item -ItemType Directory -Force $herdrDir | Out-Null
    Copy-Item (Join-Path $repoRoot 'config\herdr\config.toml') $herdrCfg -Force
    # the config's Claude keys load claude.cjs from beside it
    Copy-Item (Join-Path $repoRoot 'config\herdr\claude.cjs') (Join-Path $herdrDir 'claude.cjs') -Force
    Write-Host "Herdr config installed to $herdrCfg"
    Write-Host "  (herdr already running? apply it with: herdr server reload-config)"
    herdr integration install claude
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "herdr integration install claude failed (exit $LASTEXITCODE). Until it is installed, herdr cannot resume Claude sessions after a restart. Retry by hand."
    }
    herdr integration status
}
else {
    Write-Host "Herdr not found - skipped (optional). To add it, install it, then re-run this installer in a new terminal:"
    Write-Host '  powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"'
}

# 7. Login and keys - never stored, never echoed
Write-Host ""
Write-Host "== Login and keys ==" -ForegroundColor Yellow
Write-Host "  Models run on your Claude subscription: run claude and /login if you have not."
Write-Host '  [Environment]::SetEnvironmentVariable("FIRECRAWL_API_KEY","<optional-firecrawl-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("GEMINI_API_KEY","<optional-key-for-kopipasta-ask>","User")'
Write-Host "  (no Firecrawl key? run: claude mcp remove --scope user firecrawl)"

# 8. Verify
$claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
Write-Host ""
Write-Host "== Agent roster ==" -ForegroundColor Cyan
Get-ChildItem (Join-Path $claudeDir 'agents') -Filter *.md | ForEach-Object { "  $($_.BaseName)" }
Write-Host ""
Write-Host "== MCP servers ==" -ForegroundColor Cyan
claude mcp list | Select-String -Pattern '^(firecrawl|playwright)' | ForEach-Object { "  $($_.Line)" }
Write-Host ""
Write-Host "Done. Expected agents: quick, boss, coder."
Write-Host "      Expected MCP servers: firecrawl and playwright, both connected."
Write-Host "Try:  claude --agent quick   (claude --agent boss for the hard work)"
