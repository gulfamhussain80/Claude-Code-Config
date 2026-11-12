// PreToolUse hook for Bash and PowerShell (config/settings.json). It holds
// the two rules Claude Code's permission lists cannot express:
//   1. Network commands reach only localhost. Deny rules win over allow
//      rules there, so "deny curl, allow curl localhost" needs a hook.
//   2. The coder subagent never changes git state: it shares its caller's
//      working tree, and the caller owns history. Subagent frontmatter can
//      remove a whole tool but not single commands.
// Exit 2 blocks the call and shows stderr to the model.
'use strict';

const network = /^(curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr|irm)\b/i;
const local = /localhost|127\.0\.0\.1/;
const gitState = /^git\s+(commit|push|reset|checkout|switch|restore|stash|rebase|merge|cherry-pick|revert|tag)\b/;

const input = JSON.parse(require('node:fs').readFileSync(0, 'utf8'));
const parts = String(input.tool_input.command).split(/&&|\|\||[;|&\n]/).map((part) => part.trim());

for (const part of parts) {
  if (network.test(part) && !local.test(part)) {
    console.error('Denied by policy: the shell reaches only localhost. Use the web tools for anything else.');
    process.exit(2);
  }
  if (input.agent_type === 'coder' && gitState.test(part)) {
    console.error('Denied by policy: coder never changes git state. Report your diff; the caller commits.');
    process.exit(2);
  }
}
