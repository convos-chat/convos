<user-input>
  <form method="post" onsubmit={sendMessage}>
    <!-- div class="actions">
      <a href="#attach" class="tooltipped" title="Attach file"><i class="material-icons">attach_file</i></a>
      <a href="#webcam" class="tooltipped" title="Take picture"><i class="material-icons">photo_camera</i></a>
      <a href="#emoji" class="tooltipped" title="Insert emoji"><i class="material-icons">insert_emoticon</i></a>
      <a href="#send" onclick={sendMessage} class="tooltipped" title="Send message"><i class="material-icons">send</i></a>
    </div -->
    <textarea name="message" class="materialize-textarea" placeholder={placeholder} onkeydown={onChange}></textarea>
  </form>
  <script>
  var tag = this;
  mixin.autocomplete(this);
  this.placeholder = '';
  this.user = opts.user;

  // override autocompleteList() in "autocomplete" mixin
  autocompleteList(before, needle, after) {
    return Object.keys(opts.dialog.users()).map(function(str) {
      if (before.length == 0) str = str + ': ';
      if (after.match(/^\S/)) str = str + ' ';
      return str;
    });
  };

  onChange(e) {
    switch (e.keyCode) {
      case 9:  // tab
        this.autocomplete(this.message, e.shiftKey);
        return false;
      case 13: // enter
        if (e.shiftKey) return true;
        this.sendMessage(e);
        return false;
      case 16: // shift key
        break;
      default:
        this.autocompleteMatches = null; // reset autocomplete() when character is pressed
        return true;
    }
  }

  sendMessage(e) {
    var m = this.message.value;
    if (!m.length) return;
    opts.dialog.send(m, function(err) {
      if (!err) return;
      this.addMessage({special: 'error', message: 'Could not send "' + m + '": ' + err[0].message});
      tag.parent.update();
    });
    this.message.value = '';
    this.message.focus();
  }

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

  this.user.on('insertIntoInput', function(str) {
    var input = tag.message;
    var pos = input.selectionStart;
    var before = input.value.substring(0, pos);
    var after = input.value.substring(pos);
    if (before.length == 0) str = str + ': ';
    if (before.match(/\S$/)) str = ' ' + str;
    if (after.match(/^\S/)) str = str + ' ';
    input.value = before + str + after;
    input.focus();
    pos += str.length;
    input.selectionStart = pos;
    input.selectionEnd = pos;
  });
  </script>
</user-input>
