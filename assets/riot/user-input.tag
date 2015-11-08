<user-input>
  <div class="user-input">
    <form method="post" onsubmit={sendMessage}>
      <textarea name="message" class="materialize-textarea" disabled={!enabled} placeholder={placeholder} onkeydown={onChange}></textarea>
      <button class="btn-flat tooltipped" type="submit" if={canSend}><i class="material-icons">send</i></button>
      <a class="btn-flat dropdown-button" href="#menu_for_conversation" data-activates="menu_for_conversation" if={!canSend}><i class="material-icons">more_vert</i></a>
    </form>
    <ul id="menu_for_conversation" class="dropdown-content">
      <li><a href="#close:conversation">Close conversation</a></li>
      <li><a href="#topic">Get topic</a></li>
      <li><a href="#participants">Participants</a></li>
    </ul>
  </div>
  <script>

  this.placeholder = 'Not currently in a conversation.';
  this.canSend = false;

  onChange(e) {
    if (e.keyCode == 13 && this.canSend && !e.shiftKey) {
      this.sendMessage(e);
    }
    else {
      this.canSend = this.message.value.length == 0 ? false : true;
    }

    return true;
  }

  sendMessage(e) {
    console.log(this.message.value); // TODO
    this.canSend = false;
    this.message.value = '';
    this.message.focus();
  }

  this.on('mount', function() {
    $('.dropdown-button', this.root).dropdown({constrain_width: false});
    this.message.focus();
  });

  this.on('update', function() {
    if (opts.conversation) {
      var state = opts.conversation.connection().state();
      if (this.enabled = state == 'connected') {
        this.placeholder = 'What do you want to say to ' + this.opts.conversation.name() + '?';
      }
      else {
        this.placeholder = 'State is "' + state + '".';
      }
    }
  });

  </script>
</user-input>
