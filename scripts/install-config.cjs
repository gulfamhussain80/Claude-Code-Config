// Installs this repo's Claude Code config into ~/.claude (or
// CLAUDE_CONFIG_DIR). Run by install.sh and install.ps1; one script so
// both platforms merge the same way.
// ~/.claude belongs to the user, so nothing here mirrors a whole folder:
// - settings.json: only the keys in config/settings.json are set; allow,
//   deny and additionalDirectories are unioned; everything else is kept.
// - agents and skills: copied by name. The manifest records what this
//   repo installed, so a later install removes only what it once shipped.
// - CLAUDE.md: one import line is appended; the instructions live in
//   their own file.
'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const repo = path.dirname(__dirname);
const dir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const stamp = process.argv[2];
const guard = 'claude-config-guard.cjs';
const instructions = 'standing-instructions.md';
const manifestPath = path.join(dir, 'claude-code-config.json');

const readJson = (file, fallback) => (fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : fallback);
const union = (theirs = [], ours) => [...theirs.filter((item) => !ours.includes(item)), ...ours];

function backup(file) {
  if (!fs.existsSync(file)) return;
  fs.copyFileSync(file, `${file}.bak-${stamp}`);
  console.log(`Backed up ${file} -> ${file}.bak-${stamp}`);
}

function mergeSettings() {
  const file = path.join(dir, 'settings.json');
  backup(file);
  const ours = readJson(path.join(repo, 'config', 'settings.json'));
  const live = readJson(file, {});
  const { allow, deny, additionalDirectories, ...flags } = ours.permissions;
  live.env = { ...live.env, ...ours.env };
  live.permissions = {
    ...live.permissions,
    ...flags,
    additionalDirectories: union(live.permissions?.additionalDirectories, additionalDirectories),
    allow: union(live.permissions?.allow, allow),
    deny: union(live.permissions?.deny, deny),
  };
  const others = (live.hooks?.PreToolUse ?? []).filter((entry) => !JSON.stringify(entry).includes(guard));
  live.hooks = { ...live.hooks, PreToolUse: [...others, ...ours.hooks.PreToolUse] };
  fs.writeFileSync(file, `${JSON.stringify(live, null, 2)}\n`);
}

function installInstructions() {
  fs.copyFileSync(path.join(repo, 'config', 'instructions.md'), path.join(dir, instructions));
  const file = path.join(dir, 'CLAUDE.md');
  const line = `@${instructions}`;
  const text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (text.split(/\r?\n/).includes(line)) return;
  backup(file);
  fs.writeFileSync(file, `${text}${text && !text.endsWith('\n') ? '\n' : ''}${text ? '\n' : ''}${line}\n`);
}

// Copies each shipped entry into ~/.claude/<kind> and removes the ones an
// earlier install put there that the repo no longer ships.
function sync(kind, source, shipped, installed = []) {
  const target = path.join(dir, kind);
  fs.mkdirSync(target, { recursive: true });
  for (const name of installed.filter((item) => !shipped.includes(item))) {
    fs.rmSync(path.join(target, name), { recursive: true, force: true });
    console.log(`  removed ${kind}/${name} (no longer shipped)`);
  }
  for (const name of shipped) {
    fs.rmSync(path.join(target, name), { recursive: true, force: true });
    fs.cpSync(path.join(source, name), path.join(target, name), { recursive: true });
    console.log(`  -> ${kind}/${name}`);
  }
  return shipped;
}

fs.mkdirSync(path.join(dir, 'hooks'), { recursive: true });
mergeSettings();
installInstructions();
fs.copyFileSync(path.join(repo, 'config', 'hooks', guard), path.join(dir, 'hooks', guard));

const agentsDir = path.join(repo, 'config', 'agents');
const skillsDir = path.join(repo, 'skills');
const manifest = readJson(manifestPath, {});
const agents = fs.readdirSync(agentsDir).filter((name) => name.endsWith('.md'));
const skills = fs.readdirSync(skillsDir).filter((name) => fs.existsSync(path.join(skillsDir, name, 'SKILL.md')));
fs.writeFileSync(manifestPath, `${JSON.stringify({
  agents: sync('agents', agentsDir, agents, manifest.agents),
  skills: sync('skills', skillsDir, skills, manifest.skills),
}, null, 2)}\n`);
console.log(`Config installed to ${dir}`);
