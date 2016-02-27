<chat>
  <nav>
    <sidebar-notifications user={user}></sidebar-notifications>
    <sidebar-dialogs user={user}></sidebar-dialogs>
    <sidebar-settings user={user}></sidebar-settings>
  </nav>
  <connection-editor user={user} if={modal == 'connections'}></connection-editor>
  <new-dialog user={user} if={modal == 'new-dialog'}></new-dialog>
  <dialog-container dialog={dialog}></dialog-container>
  <script>
  var tag = this;

  this.user = opts.user;
  this.dialog = new Convos.Dialog();
  this.dialog.addMessage({message: 'Please wait until connections and conversations are loaded...', hr: true});

  wizard() {
    if (this.waitFor && location.hash.indexOf(this.waitFor) != -1) {
      tag.dialog.addMessage({message: 'Excellent! Now, please fill out the form and then click "Create".', hr: true});
      this.waitFor = false;
    }
  }

  this.user.on('refreshed', function() { riot.update() });

  this.user.one('refreshed', function() {
    if (!tag.user.connections().length) {
      tag.dialog.addMessage({message: 'Is this your first time here?', hr: true});
      tag.dialog.addMessage({message: 'To add a connection, click "Edit connections" in the right side menu.'});
      tag.update({waitFor: 'settings/connections'});
    }
    else if (!tag.user.dialogs().length) {
      tag.dialog.addMessage({message: 'You are not part of any dialogs.', hr: true});
      tag.dialog.addMessage({message: 'To join a dialog, click "New dialog" in the right side meny.'});
    }
    else {
      this.off('update', this.wizard);
    }
  });

  this.on('update', this.wizard);
  </script>
</chat>
