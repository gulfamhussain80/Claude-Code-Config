# Claude Code config

A global configuration for [Claude Code](https://code.claude.com) that
runs on your Claude subscription, with:

- two agents you talk to;
- one cheap implementer they delegate to;
- a vendored skill set;
- an allow/deny permission envelope;
- an optional [herdr](https://herdr.dev) workspace for many sessions.

It is a fork of
[Git-Uzair/Kilo-Code-Config](https://github.com/Git-Uzair/Kilo-Code-Config),
which builds the same harness on the Kilo CLI with API keys. Kilo cannot
use a Claude subscription: Anthropic limits subscription login to its own
clients. So this fork configures Claude Code itself. The herdr layer, the
skills, and the working rules are the same; the pane shows Claude Code's
TUI instead of Kilo's.

No API key is needed for the models. Last verified on Claude Code 2.1.322
and herdr 0.9.5, on macOS (2026-11-12). The Windows installer is ported
but has not been run.

## Agents

| Agent | Model | Role |
|---|---|---|
| **quick** | Sonnet | Small, well-defined tasks done end to end while you watch. Works alone, writes no plan files, commits only when asked. |
| **boss** | Opus @ xhigh | The hardest work: design, debugging with an unclear cause, planning, review of risky changes. Delegates errands. |
| **coder** | Haiku | Subagent for boss: implements one fully specified change test-first, runs tests and lint, reports its diff, and never commits. |
| Explore, general-purpose | built-in | Claude Code's built-in subagents, for bulky reading and research. general-purpose is pinned to Sonnet. |

**How work flows.**

- Start a session with `claude --agent quick` or `claude --agent boss`.
  herdr's Claude keys start quick.
- boss does the reasoning and the delicate edits itself.
- It delegates two kinds of work: bulky reading goes to Explore or
  general-purpose, and edits it can specify completely go to coder.
- Writes stay single-threaded: one agent edits the tree at a time, and
  boss reviews every delegated diff before committing it.
- For a risky change boss can ask general-purpose for a fresh-context
  review using the ponytail-review skill.

**Permissions are allow/deny only, so sessions never stall on approval
prompts.** Every tool is allowed by name, and a deny-list blocks
destructive commands outright: deletion, force-push, non-localhost
network, system mutation, and publishing. File tools cannot read or write
outside the project.

## Differences from the Kilo version

- **No Tab to switch agents.** Claude Code picks the agent when the
  session starts. Open a new tab for boss instead.
- **No default agent.** Plain `claude` is an ordinary Claude Code session
  under the same permissions. See the design notes for why.
- **No argon or carbon.** They are Gemini models.
- **No codebase indexing**, and compaction is Claude Code's own.

## Requirements

- Claude Code on PATH, logged in with a Claude subscription (`claude`,
  then `/login`).
- Node.js 22+ (the Firecrawl MCP server requires it) and git on PATH.
- Windows: PowerShell 7 (recommended). Windows PowerShell 5.1 also
  works, but its default execution policy on Windows clients
  (Restricted) blocks scripts, so start the installer there with
  `powershell -ExecutionPolicy Bypass -File .\install.ps1`.
  macOS/Linux: bash.
- Google Chrome, for the browser tools: the Playwright MCP server drives
  it. The installer warns when it is missing.
- Optional keys, set as user-scope environment variables (never stored in
  this repo):
  - `FIRECRAWL_API_KEY` - Firecrawl MCP for web search and scraping.
    Without it, run `claude mcp remove --scope user firecrawl`.
  - `GEMINI_API_KEY` - only for `kopipasta ask`.

Leave `ANTHROPIC_API_KEY` unset. Claude Code uses an approved API key
before the subscription login and bills the key. `/status` shows which
one is active.

## Install

```powershell
# Windows
git clone https://github.com/gulfamhussain80/Claude-Code-Config.git claude-config
cd claude-config
./install.ps1            # pinned MCP servers; -Latest for newest
```

```bash
# macOS / Linux
git clone https://github.com/gulfamhussain80/Claude-Code-Config.git claude-config
cd claude-config && ./install.sh   # --latest for newest
```

The installer:

1. checks for Claude Code and Node.js 22+;
2. installs, globally via npm and at pinned versions, the two MCP servers
   the config launches (`firecrawl-mcp@3.36.1`,
   `@playwright/mcp@0.0.84`), then checks for Google Chrome;
3. merges this config into `~/.claude` (see below);
4. registers both MCP servers at user scope with `claude mcp add`;
5. installs `kopipasta` (via `uv` or `pip`, best effort);
6. if `herdr` is on PATH, installs its config and Claude integration (see
   [Herdr](#herdr-one-place-for-many-sessions));
7. lists the installed agents and the status of both MCP servers.

**What it does to `~/.claude`.** That folder is yours, so the installer
merges instead of replacing. It backs up each file before changing it.

- `settings.json`: adds this repo's allow and deny rules, its two
  `permissions` flags, two `env` values, and one `PreToolUse` hook.
  Everything else in the file is kept.
- `CLAUDE.md`: appends one line, `@standing-instructions.md`. The
  instructions themselves live in `~/.claude/standing-instructions.md`.
- `agents/` and `skills/`: copies this repo's agents and skills by name.
  Your own are left alone. `claude-code-config.json` records what was
  installed, so a later install removes only what this repo once shipped.
- `hooks/claude-config-guard.cjs`: the hook script.

Then verify, in a new terminal:

```bash
ls ~/.claude/agents  # expect quick.md, boss.md, coder.md (plus your own)
claude mcp list      # expect firecrawl and playwright: connected
```

## Usage

```bash
# interactive session in quick
claude --agent quick

# the heavyweight
claude --agent boss

# one headless run
claude -p --agent boss "implement X with tests"

# boss at max effort for one session (its default is xhigh)
claude --agent boss --effort max

# sharpen a design by interview first
#   /grill-with-docs

# after a session: what should change in the harness itself?
#   /retro

# terse replies until "stop caveman"
#   /caveman           (/ultracave or /megacave compress harder)
```

When boss plans, the plan goes to `docs/plans/<date>-<slug>.md` in the
target repo. It ends with `PLAN COMPLETE`, and task statuses are updated
in the file as work proceeds, so a run survives restarts and compaction.

Skills update with the repo: `git pull`, then re-run the installer.

`kopipasta` is optional but assumed by the `codebase-map` skill; without
it, agents fall back to plain reads. It needs Python 3.10+. Install it by
hand with `uv tool install kopipasta` (or `pip install kopipasta`) and
check it with `kopipasta map --help`. The standard invocation is
`kopipasta map --json`.

## Herdr: one place for many sessions

[Herdr TUI](https://herdr.dev/tui/docs/) (Apache-2.0; v0.9.5 when this
was written) is optional: a terminal workspace manager for coding agents.

- Its server owns the panes, so closing the window leaves every agent
  running.
- A sidebar shows which agents are working, which are blocked waiting for
  you, and which have finished.
- After a reboot it restores the layout and reopens each conversation
  with `claude --resume <id>`. A resumed session keeps its agent, so a
  boss pane returns as boss.

**Install.**

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"
```

On macOS/Linux use `curl -fsSL https://herdr.dev/install.sh | sh`. Then
re-run `./install.ps1` (or `./install.sh`) in a new terminal. With herdr
on PATH, the installer:

1. copies `config/herdr/config.toml` to `%APPDATA%\herdr\config.toml`
   (`~/.config/herdr/config.toml` on macOS/Linux), backing up any
   existing file, and `config/herdr/claude.cjs` beside it;
2. runs `herdr integration install claude`, which adds
   `~/.claude/hooks/herdr-agent-state.sh` and its hook entry in
   `settings.json`;
3. prints `herdr integration status`.

Unlike `~/.claude`, the herdr config is replaced, not merged. If you
already have a herdr config of your own, copy the `[[keys.command]]`
blocks you want out of `config/herdr/config.toml` instead.

**Keys.** The prefix is ctrl+q, not herdr's default ctrl+b: in Claude
Code ctrl+b sends a running command or subagent to the background.

| Key | Action |
|---|---|
| `ctrl+q a` | Claude in a new tab of this workspace |
| `ctrl+q shift+a` | Claude in a new worktree; asks for a branch |
| `ctrl+q f` | Claude in another folder, as a new workspace; asks for a path |
| `ctrl+q c` | new tab with a shell |
| `ctrl+q v` / `ctrl+q -` | split right / down |
| `ctrl+q h`/`j`/`k`/`l` | move between panes |
| `ctrl+q w` | workspaces |
| `ctrl+q g` | jump to any agent |
| `ctrl+q q` | detach, leaving everything running (`herdr` reattaches) |
| `ctrl+q ?` | help |

The three Claude keys run `claude.cjs` and type `claude --agent quick`
into the new pane. `ctrl+q f` starts from the parent of the current
folder: a sibling repo is its name plus Tab. Esc cancels either prompt.

From a terminal outside herdr, an `hc` function does the same for the
current folder (or one you name), then attaches. Paste this once to add it
to your shell profile and load it in the current terminal:

```powershell
# Windows (PowerShell)
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
Add-Content $PROFILE @('', 'function hc { node "$env:APPDATA\herdr\claude.cjs" open @args }')
. $PROFILE
```

```zsh
# macOS (zsh)
printf '\nhc() { node ~/.config/herdr/claude.cjs open "$@"; }\n' >> ~/.zshrc && . ~/.zshrc
```

When herdr is not running, `hc` only starts it, which restores your last
session; press `ctrl+q f` there.

**Working with it.**

- One workspace per repo and one tab per task: `ctrl+q a`, or in a pane
  run `claude --agent quick` or `claude --agent boss`.
- Keep one writer per checkout.
- Parallel work in one repo goes into a worktree: `ctrl+q shift+a`, or
  `herdr worktree create --cwd . --branch <name>`. The checkout opens as
  its own workspace under `~/.herdr/worktrees/<repo>/<branch-slug>`.
  Remove it with `herdr worktree remove --workspace <id>` (ids come from
  `herdr workspace list`); this deletes the checkout and keeps the
  branch.
- Sessions in the same checkout share one Playwright browser profile,
  and only one of them can have the browser open at a time. A worktree is
  a different directory, so it gets its own profile.
- Panes are started by the herdr server, so an environment variable set
  after the server started may not reach new panes. Run
  `herdr server stop`, then `herdr`: the layout returns and
  conversations resume.
- Every pane running boss is a separate Opus session, and they all draw
  on the same subscription limits.

**Not used here.**

- herdr's agent skill: its distinctive feature is agents starting other
  agents in panes, which brings back parallel writers.
- The Herdr desktop app: a separate product whose agents are not shared
  with the TUI.

## Design notes

Each note says how it was checked. "Tested" means a real `claude -p`
session on Claude Code 2.1.322 (2026-11-12) against a scratch project;
"docs" means read in the Claude Code docs the same day and not run.

- **No `agent` default in `settings.json`.** Tested: with
  `"agent": "quick"` set, a boss session resumed with
  `claude --resume <id>` came back as quick, on Sonnet and without the
  Agent tool. With the key unset it came back as boss on Opus. herdr
  resumes with exactly that command, so the default would silently
  downgrade every restored boss pane. The cost is that plain `claude` is
  not quick; the herdr keys type `claude --agent quick`.
- **Deny rules win over allow rules.** Docs: Claude Code checks deny,
  then ask, then allow, and an allow rule cannot carve an exception out
  of a deny rule. Kilo's rules are last-match-wins, so two of its rules
  needed another form here.
  - `*.env` files are denied and `*.env.example` is carved back out with
    a `!` negation rule. Tested: `.env` denied, `.env.example` read.
  - "Deny curl, allow curl to localhost" has no rule form, so
    `hooks/claude-config-guard.cjs` checks network commands. Tested:
    `curl https://example.com` blocked, `curl http://localhost:9/` ran.
- **Never stall, without `dontAsk` mode.** `dontAsk` denies anything
  that would prompt, but the docs say it also denies `AskUserQuestion`,
  which the interview skills use. So sessions stay in the default mode
  and every tool is allowed by name. Tested: no step waited for approval.
  `AskUserQuestion` itself was not tested: `claude -p` has no user to ask.
- **File tools stay inside the project.** Tested:
  `blockReadsOutsideWorkingDirectories` and
  `blockWritesOutsideWorkingDirectories` refused a read and a write
  outside the project. `~/.claude/skills` is added as a readable
  directory so skills can open their own files, and an edit deny keeps it
  read-only. Shell commands are not covered by these two keys.
- **coder cannot change git state.** It shares boss's working tree, and
  commands such as checkout, reset, or stash could destroy boss's
  uncommitted work. Docs: a subagent's `disallowedTools` removes a whole
  tool, never single commands. So the guard hook blocks those git
  commands when the caller is coder. Tested: coder's `git commit` was
  blocked; the same command is allowed for boss.
- **boss cannot start quick or itself.** `Agent(quick)` and `Agent(boss)`
  are denied, and `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` stops
  subagents from starting subagents. Tested: dispatching quick failed
  with the permission rule's name.
- **An agent's prompt replaces Claude Code's system prompt.** Docs: a
  non-empty agent body replaces the default system prompt, as
  `--system-prompt` does; `CLAUDE.md` still loads. quick and boss
  therefore run on their own short prompts plus the standing
  instructions.
- **Explore runs on Opus.** Docs: on a subscription the built-in Explore
  subagent uses Opus, and `CLAUDE_CODE_SUBAGENT_MODEL` does not change
  it. The variable does pin general-purpose to Sonnet.
- **Plan mode is removed from quick and boss.** Plans are files in
  `docs/plans/`.
- **boss's effort level is not verified.** The frontmatter sets
  `effort: xhigh`; nothing in the test output confirms the level the
  session ran at.
- **Firecrawl's unused tools are not withheld.** Kilo could deny a
  server's tools and re-allow three. Here a deny would win over the
  allow, so only the three are allowed and the rest stay visible to the
  model. A session that calls one of them gets a prompt.
- **The guard hook splits commands on shell operators itself.** It is a
  policy check on the commands the model normally writes, not a sandbox:
  a network call inside `$(...)` passes it.
- **The MCP servers are installed, not fetched per session.** The
  installers put `firecrawl-mcp` and `@playwright/mcp` on PATH at pinned
  versions and register them by name. On Windows, whether Claude Code
  starts the npm `.cmd` shims by bare name has not been tested.

## What's in the box

```
config/settings.json       permissions, env, and the hook entry merged into ~/.claude/settings.json
config/instructions.md     standing instructions, imported from ~/.claude/CLAUDE.md
config/agents/*.md         the three agents (system prompt + tools each)
config/hooks/              the PreToolUse guard: localhost-only network, no git state changes for coder
config/herdr/config.toml   Herdr TUI config (optional; installed when herdr is on PATH)
config/herdr/claude.cjs    launchers behind herdr's Claude keys and `hc`
skills/                    every skill the harness ships (vendored + local codebase-map)
skills/vendor.psd1         upstream repo, pinned commit, license files per vendored skill
scripts/install-config.cjs the ~/.claude merge both installers run
scripts/sync-skills.ps1    re-vendors skills from vendor.psd1, checks dependency closure
install.ps1 / install.sh   one-shot setup
docs/plans/                plans from the upstream Kilo repo, kept as history
```

## Skills

Every skill the harness ships is in `skills/`. The installers copy each
one into `~/.claude/skills` by name and leave your other skills alone.

Third-party skills are vendored byte-for-byte at the commits pinned in
`skills/vendor.psd1` (last refreshed to upstream HEAD on 2026-11-04).
Each folder carries its upstream license.

- [mattpocock/skills](https://github.com/mattpocock/skills) (MIT):
  `tdd`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`,
  `grilling`, `grill-with-docs`, `retro`, `writing-for-agents`.
- [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
  (Apache-2.0, NOTICE included): `caveman`, `ultracave`, `megacave`. Only
  the skill folders are vendored, not the Caveman CLI, proxy, or gateway.
- [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
  (MIT): `ponytail` (the smallest change that fully solves the task) and
  `ponytail-review`. ponytail-review is a full quality review:
  correctness, safety, load, tests, speed, and leanness, with numbered
  findings and a verdict.
- [anthropics/skills](https://github.com/anthropics/skills)
  (Apache-2.0): `frontend-design`.

There is one local skill (MIT, same as the config): `codebase-map`. It
maps a repository's symbols with
[kopipasta](https://github.com/mkorpela/kopipasta) before any file is
read, so exploration costs one command instead of a fan-out of reads.

Every skill that a shipped skill depends on ships too, and
`scripts/sync-skills.ps1` re-checks that on every sync.

To refresh the vendored skills (maintainers):

1. Run `./scripts/sync-skills.ps1 -Latest`.
2. Review `git diff -- skills`.
3. Paste the printed commits into `skills/vendor.psd1`.
4. Commit.

## License

MIT - see [LICENSE](LICENSE). Vendored skills under `skills/` keep their
upstream licenses (MIT or Apache-2.0), and each vendored folder carries
its license file(s).
