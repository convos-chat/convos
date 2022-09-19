export const channelModeCharToModeName = {
  b: 'channel_ban',
  C: 'ctcp_block',
  c: 'colour_filter',
  e: 'ban_exemption',
  F: 'enable_forwarding',
  f: 'forward',
  g: 'free_invite',
  i: 'invite_only',
  I: 'invite_exemption',
  j: 'join_throttle',
  k: 'password',
  l: 'join_limit',
  L: 'large_ban_list',
  m: 'moderated',
  M: 'login_to_talk',
  n: 'prevent_external_send',
  P: 'permanent',
  p: 'privat',
  Q: 'block_forwarded_users',
  q: 'quiet',
  r: 'block_unidentified',
  R: 'login_to_join',
  s: 'secret',
  S: 'secure_connection_only',
  t: 'topic_protection',
};

export function getChannelMode(mode) {
  if (channelModeCharToModeName[mode]) return channelModeCharToModeName[mode];
  return Object.keys(channelModeCharToModeName).filter(k => mode === channelModeCharToModeName[k])[0] || '';
}

export const modeMoniker = {
  a: '&',
  h: '%',
  o: '@',
  q: '~',
  v: '+',
};

export const userModeCharToModeName = {
  a: 'admin',
  B: 'bot',
  h: 'half_operator',
  i: 'invisible',
  I: 'whois_hide_online',
  o: 'operator',
  p: 'whois_hide_channels',
  R: 'privmsg_from_registered_only',
  r: 'registered',
  S: 'service_bot',
  T: 'ctcp_block',
  t: 'vhost',
  v: 'voice',
  W: 'whois_notifications',
  x: 'cloaked_hostname',
  z: 'secure_connection',
  Z: 'secure_connection_only',
};
