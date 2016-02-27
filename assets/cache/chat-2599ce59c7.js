riot.tag2('chat', '<nav> <sidebar-notifications user="{user}"></sidebar-notifications> <sidebar-dialogues user="{user}"></sidebar-dialogues> <sidebar-settings user="{user}"></sidebar-settings> </nav> <connection-editor user="{user}" if="{modal == \'connections\'}"></connection-editor> <dialogue dialogue="{dialogue}"></dialogue>', '', '', function(opts) {
  var tag = this;

  this.user = opts.user;
  this.dialogue = new Convos.Dialogue();
  this.dialogue.addMessage({message: 'Please wait until connections and conversations are loaded...', hr: true});

  this.wizard = function() {
    if (this.waitFor && location.hash.indexOf(this.waitFor) != -1) {
      tag.dialogue.addMessage({message: 'Excellent! Now, please fill out the form and then click "Create".', hr: true});
      this.waitFor = false;
    }
  }.bind(this)

  this.user.one('refreshed', function() {
    if (!tag.user.connections().length) {
      tag.dialogue.addMessage({message: 'Is this your first time here?', hr: true});
      tag.dialogue.addMessage({message: 'To add a connection, click "Edit connections" in the right side menu.'});
      tag.update({waitFor: 'settings/connections'});
    }
    else if (!tag.user.dialogues().length) {
      tag.dialogue.addMessage({message: 'You are not part of any dialogues.', hr: true});
      tag.dialogue.addMessage({message: 'To join a dialogue, click "New dialogue" in the right side meny.'});
    }
    else {
      this.off('update', this.wizard);
    }
  });

  this.on('update', this.wizard);
}, '{ }');
