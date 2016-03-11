riot.tag2('user-input', '<form method="post" onsubmit="{sendMessage}"> <textarea name="message" class="materialize-textarea" placeholder="{placeholder}" onkeydown="{onChange}"></textarea> </form>', '', '', function(opts) {
  mixin.autocomplete(this);

  this.placeholder = '';

  this.onChange = function(e) {
    switch (e.keyCode) {
      case 9:
        this.autocomplete(this.message, e.shiftKey);
        return false;
      case 13:
        if (e.shiftKey) return true;
        this.sendMessage(e);
        return false;
      case 16:
        break;
      default:
        this.autocompleteMatches = null;
        return true;
    }
  }.bind(this)

  this.sendMessage = function(e) {
    var m = this.message.value;
    if (!m.length) return;
    opts.dialog.send(m, function(err) {
      if (!err) return;
      this.addMessage({special: 'error', message: 'Could not send "' + m + '": ' + err[0].message});
      tag.parent.update();
    });
    this.message.value = '';
    this.message.focus();
  }.bind(this)

  this.on('mount', function() {
    $('.dropdown-button', this.root).dropdown({constrain_width: false});
    this.message.focus();
  });

  this.on('update', function() {
    try {
      var state = opts.dialog.connection().state();
      if (state == 'connected') {
        this.placeholder = 'What do you want to say to ' + this.opts.dialog.name() + '?';
      }
      else {
        this.placeholder = 'State is "' + state + '".';
      }
    } catch (err) {
      this.placeholder = 'Please enter commands as instructed.';
    };
  });

}, '{ }');
