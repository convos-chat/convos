Convos.commands = [
  {
    command: "close",
    description: "Close conversation with nick, defaults to current active.",
    example: "/close <nick>"
  },
  {
    command: "join",
    aliases: ["j"],
    description: "Join channel and open up a chat window.",
    example: "/join <#channel>"
  },
  {
    command: "kick",
    description: "Kick a user from the current channel.",
    example: "/kick <nick>"
  },
  {
    command: "me",
    description: "Send message as an action.",
    example: "/me <msg>"
  },
  {
    command: "msg",
    description: "Send a direct message to nick.",
    example: "/msg <nick> <msg>"
  },
  {
    command: "nick",
    description: "Change your wanted nick.",
    example: "/nick <nick>"
  },
  {
    command: "part",
    description: "Leave channel, and close window.",
    example: "/part"
  },
  {
    command: "query",
    aliases: ["q"],
    description: "Open up a new chat window with nick.",
    example: "/query <nick>"
  },
  {
    command: "mode",
    description: "Change mode of yourself or a user"
  },
  {
    command: "names",
    description: "Show participants in the channel."
  },
  {
    command: "reconnect",
    description: "Restart the current connection."
  },
  {
    command: "say",
    description: 'Used when you want to send a message starting with "/".',
    example: "/say <msg>"
  },
  {
    command: "topic",
    description: "Show current topic, or set a new one.",
    example: "/topic or /topic <new topic>"
  },
  {
    command: "whois",
    description: "Show information about a user.",
    example: "/whois <nick>"
  },
  {
    command: "cs",
    alias_for: "/msg chanserv",
    description: 'Short for "/msg chanserv ...".',
    example: "/cs <msg>"
  },
  {
    command: "ns",
    alias_for: "/msg nickserv",
    description: 'Short for "/msg nickserv ...".',
    example: "/ns <msg>"
  }
];
