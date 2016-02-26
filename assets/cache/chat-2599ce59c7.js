riot.tag2('chat', '<nav> <sidebar-search user="{user}"></sidebar-search> <sidebar-notifications user="{user}"></sidebar-notifications> <sidebar-dialogues user="{user}"></sidebar-dialogues> <sidebar-settings user="{user}"></sidebar-settings> </nav> <dialogue dialogue="{dialogue}"></dialogue>', '', '', function(opts) {
  this.user = opts.user;
  this.dialogue = this.user.dialogues()[0];
}, '{ }');
