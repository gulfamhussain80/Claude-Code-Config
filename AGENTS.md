# AGENTS.md

Facts every agent needs when working in THIS repository. Read once, trust,
do not re-derive.

- This repo is prose and configuration: the Claude Code settings it
  merges (`config/settings.json`), standing instructions
  (`config/instructions.md`), agent prompts (`config/agents/*.md`),
  installers, and every skill the harness ships (`skills/`). Nothing here
  executes at runtime except the installers with
  `scripts/install-config.cjs`, `config/hooks/claude-config-guard.cjs`
  (a PreToolUse hook), `config/herdr/claude.cjs` (run by herdr's Claude
  keys), and the maintainer-run `scripts/sync-skills.ps1`.
- It is a fork of Git-Uzair/Kilo-Code-Config (the `upstream` remote),
  which targets the Kilo CLI. `docs/plans/` holds upstream's plans and is
  history, not a description of this repo.
- `skills/` holds vendored third-party skills (byte copies at the
  commits pinned in `skills/vendor.psd1`) plus the local `codebase-map`.
  Never hand-edit a vendored folder - the next sync overwrites it; adapt
  the harness around a skill in `config/` instead.
- There is NO test suite, NO build, and NO lint command - and none should
  ever be bootstrapped. Changes here are verified by reading the diff
  against the request. Changes under `config/` can also be checked
  without touching the live config:
  - `CLAUDE_CONFIG_DIR=<tmp> node scripts/install-config.cjs test` runs
    the merge into a scratch folder.
  - A scratch config folder has no login. To run a real session, copy
    the scratch `agents/` and `skills/` into `<project>/.claude/`, point
    the hook path in a copy of `config/settings.json` at the scratch
    hook, and run `claude -p --setting-sources project --settings
    <that copy> --agent <name> "..."` inside the project.
- Prose wraps at roughly 76 columns. That is a style preference for new
  text you write - never an acceptance criterion, never a verification
  finding, and never a reason to re-wrap lines you did not otherwise
  touch.
- This repo is the source of truth that the installers copy FROM. The
  installed live config lives in `~/.claude/` - editing that directly is
  always wrong here; edit `config/` and re-run the installer.
- `~/.claude` belongs to the user, not to this repo. The installers
  merge into `settings.json`, append one import line to `CLAUDE.md`, and
  copy agents and skills by name; they must never replace or mirror a
  whole folder there. `~/.claude/claude-code-config.json` is the manifest
  of what was installed.
- `~/.claude/hooks/herdr-agent-state.sh` and its hook entry in
  `settings.json` belong to herdr: `herdr integration install claude`
  writes them. The settings merge must keep hook entries it does not own.
- `config/settings.json` must not set `"agent"`: the default agent
  overrides the agent of a resumed session (README design notes).
- Permission rules are deny-first. An allow rule cannot carve an
  exception out of a deny rule; use a `!` negation rule for paths or the
  guard hook for commands.
- The MCP servers (`firecrawl`, `playwright`) launch installed binaries
  by name; both installers pin their npm packages and register them with
  `claude mcp add`. Changing a server's package, version, or command
  means updating both installers and the allow rules in
  `config/settings.json` in the same change.
- An agent's name is its `name` field, matched by its filename in
  `config/agents/`. Renaming or removing one means updating, in the same
  change: the `Agent(...)` deny rules in `config/settings.json`, the
  `agent_type` check in the guard hook, `config/herdr/claude.cjs` when
  it is the agent the herdr keys start, the installers' expected-roster
  lines, and the README.
- Commits go straight to `main`, one commit per task, message style per
  `git log` (`feat:`, `fix:`, `docs:`, `chore:`, `agents:`). Push only
  when asked.
