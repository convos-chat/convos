riot.tag2('user-input', '<form method="post" onsubmit="{sendMessage}"> <textarea name="message" class="materialize-textarea" placeholder="{placeholder}" onkeydown="{onChange}"></textarea> </form>', '', '', function(opts) {
  var tag = this;
  mixin.autocomplete(this);
  this.placeholder = '';
  this.user = opts.user;

  this.autocompleteList = function(before, needle, after) {
    return opts.dialog.participants().map(function(p) { return p.name; }).map(function(n) {
      if (before.length == 0) n = n + ': ';
      if (after.match(/^\S/)) n = n + ' ';
      return n;
    });
  }.bind(this);

  this.localCmdHelp = function(e) {
    riot.route('/settings/help');
  }.bind(this)

  this.localCmdJoin = function(e) {
    riot.route('/settings/new-dialog');
  }.bind(this)

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
    var l = 'localCmd' + m.replace(/^\//, '').ucFirst();
    this.message.value = '';
    if ('localCmd' + m != l && this[l]) return this[l](e);
    if (m.length) return opts.dialog.send(m);
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
}, '{ }');
