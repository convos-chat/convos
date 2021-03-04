import {md} from './md';

export const commands = [];
export const rewriteRule = {};

export function commandOptions({query}) {
  const opts = [];

  for (let i = 0; i < commands.length; i++) {
    if (commands[i].cmd.indexOf(query) != 0) continue;
    const val = commands[i].alias || commands[i].cmd;
    opts.push({val, text: md(commands[i].example)});
  }

  return opts;
}

export function normalizeCommand(command) {
  const parts = command.split(/\s/);
  const rule = rewriteRule[parts[0].toLowerCase()];
  if (rule) return [rule].concat(parts.slice(1)).filter(p => typeof p != 'undefined' && p.length).join(' ');
  return command;
}

const add = (cmd, example, description) => commands.push({cmd, description, example});

// The order is based on the (subjective) frequency of the command
add('/me', '/me <msg>', 'Send message as an action.');
add('/say', '/say <msg>', 'Used when you want to send a message starting with "/".');
add('/whois', '/whois <nick>', 'Show information about a user.');
add('/query', '/query <nick>', 'Open up a new chat window with nick.');
add('/msg', '/msg <nick> <msg>', 'Send a direct message to nick.');
add('/join', '/join <#channel>', 'Join channel and open up a chat window.');
add('/close', '/close [nick|#channel]', 'Close conversation.');
add('/nick', '/nick <nick>', 'Change your wanted nick.');
add('/kick', '/kick <nick>', 'Kick a user from the current channel.');
add('/mode', '/mode [+|-][b|o|v] <user>', 'Change mode of yourself or a user');
add('/topic', '/topic or /topic <new topic>', 'Show current topic, or set a new one.');
add('/names', '/names', 'Show participants in the channel.');
add('/invite', '/invite <nick> [#channel]', 'Invite a user to a channel.');
add('/reconnect', '/reconnect', 'Restart the current connection.');
add('/clear', '/clear history <#channel> or /clear history <nick>', 'Delete all history for the given conversation.');
add('/oper', '/oper <msg>', 'Send server operator messages.');
add('/cs', '/cs <msg>', 'Send a message to chanserv.');
add('/ns', '/ns <msg>', 'Send a message to nickserv.');
add('/quote', '/quote <irc-command>', 'Allow you to send any raw IRC message.');

const addRewriteRule = (cmd, rule) => (rewriteRule[cmd] = rule);

addRewriteRule('/close', '/part');
addRewriteRule('/cs', '/msg chanserv');
addRewriteRule('/j', '/join');
addRewriteRule('/ns', '/msg nickserv');
addRewriteRule('/raw', '/quote');
