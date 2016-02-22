riot.tag2('chat', '<nav> <sidebar-search user="{user}"></sidebar-search> <sidebar-conversations user="{user}"></sidebar-conversations> <sidebar-notifications user="{user}"></sidebar-notifications> <sidebar-settings user="{user}"></sidebar-settings> </nav> <conversation conversation="{conversation}"></conversation> <conversation conversation="{conversation}"></conversation>', '', '', function(opts) {
  this.user = opts.user;
  this.conversation = this.user.conversations()[0];
}, '{ }');
