riot.tag2('user-input', '<div class="user-input"> <form method="post" onsubmit="{sendMessage}"> <textarea name="message" class="materialize-textarea" __disabled="{!canSend}" placeholder="{placeholder}" onkeydown="{onChange}"></textarea> <a class="btn-flat dropdown-button" href="#menu_for_conversation" data-activates="menu_for_conversation"><i class="material-icons">more_vert</i></a> </form> <ul id="menu_for_conversation" class="dropdown-content"> <li><a href="#close:conversation">Close conversation</a></li> <li><a href="#topic">Get topic</a></li> <li><a href="#participants">Participants</a></li> </ul> </div>', '', '', function(opts) {

  this.placeholder = 'Not currently in a conversation.';
  this.canSend = false;

  this.onChange = function(e) {
    switch (e.keyCode) {
      case 13:
        if (e.shiftKey) return true;
        this.sendMessage(e);
        return false;
      default:
        return true;
    }
  }.bind(this)

  this.sendMessage = function(e) {
    opts.conversation.send(this.message.value, function(err) {
      if (err) console.log(err);
    }.bind(this));
    this.message.value = '';
    this.message.focus();
  }.bind(this)

  this.on('mount', function() {
    $('.dropdown-button', this.root).dropdown({constrain_width: false});
    this.message.focus();
  });

  this.on('update', function() {
    if (opts.conversation) {
      var state = opts.conversation.connection().state();
      if (this.canSend = state == 'connected') {
        this.placeholder = 'What do you want to say to ' + this.opts.conversation.name() + '?';
      }
      else {
        this.placeholder = 'State is "' + state + '".';
      }
    }
  });

}, '{ }');
