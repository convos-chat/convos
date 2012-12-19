var BASEURL = window.location.href;

(function($) {

Structure.registerModule('Wirc', {
  websocket: function(path, callbacks) {
    var url = BASEURL.replace(/^http/, 'ws') + path;
    var websocket = new ReconnectingWebSocket(BASEURL.replace(/^http/, 'ws') + '/socket');
    if(window.console) console.log('[websocket] ' + url);
    $.each(callbacks, function(name, callback) { websocket[name] = callback; });
    return websocket;
  }
}); // End Wirc

Structure.registerModule('Wirc.Notifier', {
  init: function() {
    var self = this;

    if(!window.webkitNotifications) {
      return self;
    }
    if(!webkitNotifications.checkPermission()) { // already granted
      self.notifier = webkitNotifications;
      return self;
    }

    // cannot run requestPermission() without a user action, such as mouse click or key down
    $(document).one('keydown', function() {
      webkitNotifications.requestPermission(function(e) {
        if(window.console) console.log(e);
        if(!webkitNotifications.checkPermission()) self.notifier = notifier;
      });
    });

    return self;
  },
  notify: function(icon, title, msg) {
    if(!this.notifier) return;
    var notification = this.notifier.createNotification(icon || '', title, msg || '');
    notification.show();
  }
}); // End Wirc.Notify

Structure.registerModule('Wirc.Chat', {
  parseIrcMessage: function(d) {
    var data = $.parseJSON(d);
    var action = data.message ? data.message.match(/^\u0001ACTION (.*)\u0001$/) : [];

    data.template = 'message_template';

    if(action.length) {
      data.message = action[1];
      data.template = 'action_message_template';
    }
    if(data.message) {
      data.highlight = data.message.match("\\b" + this.nick + "\\b") ? 1 : 0;
      data.message = data.message.replace(/</i, '&lt;').replace(/\b(\w{2,5}:\/\/\S+)/g, '<a href="$1" target="_blank">$1</a>');
    }
    if(data.timestamp) {
      data.timestamp = new Date(parseInt(data.timestamp*1000, 10));
    }

    data.class_name = data.nick === this.nick                             ? 'me'
                    : data.highlight                                      ? 'focus'
                    : $('#chat_messages').find('li:last').hasClass('odd') ? 'even'
                    :                                                       'odd';

    return data;
  },
  channels: function(data) {
    if(!data) return []; // TODO: return channel names

    var id = (data.joined || data.parted).replace(/\W/, '');
    var $channel = $('#target_' + data.cid + '_' + id);

    if(data.parted) {
      $channel.remove();
    }
    else if(data.joined && !$channel.length) {
      $(tmpl('new_channel_template', data)).insertAfter('#connection_list_' + data.cid + ' .channel:last');
    }

    return this; // allow chaining
  },
  conversations: function(data) {
    if(!data) return []; // TODO: return conversation list

    var id = data.nick.replace(/\W/, '');
    var $conversation = $('#target_' + data.cid + '_' + id);

    if(!$conversation.length) {
      $(tmpl('new_conversation_template', data)).appendTo('#connection_list_' + data.cid);
    }

    return this; // allow chaining
  },
  displayUnread: function(data) {
    var $badge = $('#target' + '_' + data.cid + '_' + channel_id + ' .badge');
    $badge.text(parseInt($badge.text(), 10) + 1 ).show();
    if(data.highlight) $badge.addClass('badge-important');
  },
  scrollToBottom: function() {
    $('html, body').scrollTop($('body').height());
  },
  print: function(data) {
    var at_bottom = $(window).scrollTop() + $(window).height() >= $('body').height() - 30; // need to calculate at_bottom before appending a new element
    var $messages = this.$messages;

    if(data.status) {
      if(data.status == this.status) return; // do not want duplicate status messages
      if(data.message) $messages.append(tmpl('server_status_template', data));
      this.status = data.status;
    }
    else if(data.new_nick && data.cid === this.connection_id) {
      $messages.append(tmpl('nick_change_template', data));
    }
    else if(data.nick !== this.nick && data.joined === this.target) {
      $messages.append( $(tmpl('nick_joined_template', data)) );
    }
    else if(data.message && data.target == this.target || data.nick == this.target) {
      $messages.append(tmpl(data.template, data));
    }

    if(at_bottom) {
      this.scrollToBottom();
    }
  },
  receiveData: function(e) {
    var data = this.parseIrcMessage(e.data);
    var channel_id;

    if(window.console) console.log('[websocket] > ' + e.data);

    // notification handling
    if(!self.window_has_focus) {
      if(data.highlight) {
        this.notifier.notify('', 'New mention by ' + data.nick + ' in ' + data.target, data.message);
      }
      else if(data.target === this.nick) {
        this.notifier.notify('', 'New message from ' + data.nick, data.message);
      }
      if(data.cid == this.connection_id && data.target == this.target) {
        document.title = 'New message in ' + this.target;
      }
    }

    // action handling
    if(data.joined || data.parted) {
      this.channels(data);
    }
    else if(data.target) {
      if(data.target === this.nick && data.target !== this.target && this.target != this.nick) {
        this.conversations(data);
      }
      if(data.target !== this.target) {
        this.displayUnread(data);
      }
    }
    else if(data.new_nick) {
      this.input.autoCompleteNicks(data);
      if(this.nick === data.old_nick) this.nick = this.new_nick;
    }

    this.print(data);
  },
  sendData: function(data) {
    // TODO: Figure out if JSON.stringify() works in other browsers than chrome
    try {
      this.websocket.send(JSON.stringify(data));
      if(window.console) console.log('[websocket] < ' + JSON.stringify(data));
    } catch(e) {
      if(window.console) console.log('[websocket] ! ' + e);
      this.print({ error: '[ws]' + e });
    }
  },
  listenToScroll: function() {
    var $win = $(window);
    var $messages = $('#chat_messages');
    var $loading;
    var page = 1;
    var height;

    $win.on('scroll', function() {
      if($loading || $win.scrollTop() !== 0) return;
      $loading = $('<div class="alert alert-info">Loading previous conversations...</div>');
      height = $('body').height();
      page++;
      $messages.before($loading);
      if(window.console) console.log(BASEURL + '/history/' + page);
      $.ajax({
        url: BASEURL + '/history/' + page,
        success: function(data) {
          var $li = $(data).find('#chat_messages li');
          if($li.length) {
            $messages.prepend($li);
            $loading.remove();
            $loading = false;
            $win.scrollTop($('body').height() - height);
          }
          else {
            $loading.removeClass('alert-info').text('End of conversation log.');
          }
        }
      });
    });
  },
  init: function($) {
    var self = this;
    var original_title = document.title;

    self.$messages = $('#chat_messages');
    self.connection_id = $('#chat_messages').attr('data-cid');
    self.nick = $('#chat_messages').attr('data-nick');
    self.target = $('#chat_messages').attr('data-target');
    self.input = Wirc.Chat.Input.init($('#chat_input_field input[type="text"]'));
    self.notifier = Wirc.Notifier.init();
    self.scrollToBottom();
    self.listenToScroll();

    self.websocket = Wirc.websocket('/socket', {
      onmessage: self.receiveData,
      onopen: function function_name (argument) {
        self.sendData({ cid: self.connection_id, target: self.target });
      }
    });

    self.input.submit = function(e) {
      self.sendData({ cid: self.connection_id, target: self.target, cmd: this.$input.val() });
      this.$input.val(''); // TODO: Do not clear the input field until echo is returned?
      return false;
    };

    $.each($('#chat_messages').attr('data-nicks').split(','), function(i, v) {
      if(v == this.nick) return;
      self.input.autoCompleteNicks({ new_nick: v.replace(/^\@/, '') });
    });

    $(window).blur(function() { self.window_has_focus = false; });
    $(window).focus(function() { self.window_has_focus = true; document.title = original_title; });
    if(window.console) console.log('[Wirc.Chat.init] ', self);

    return self;
  }
}); /* End Structure.registerModule('Wirc.Chat') */

Structure.registerModule('Wirc.Chat.Input', {
  autocomplete: [
    '/join #',
    '/msg ',
    '/me ',
    '/nick ',
    '/part '
  ],
  autoCompleteNicks: function(data) {
    if(data.old_nick) {
      var needle = data.old_nick;
      this.autocomplete = $.grep(this.autocomplete, function(v, i) {
        return v != needle;
      });
    }
    if(data.new_nick) {
      this.autoCompleteNicks({ old_nick: data.new_nick });
      this.autocomplete.unshift(data.new_nick);
    }
  },
  tabbing: function(val) {
    var complete;

    if(val === false) {
      delete this.tabbed;
      return this;
    }
    if(typeof this.tabbed === 'undefined') {
      var offset = val.lastIndexOf(' ') + 1;
      var re = new RegExp('^' + val.substr(offset));

      this.autocomplete_offset = offset;
      this.matched = $.grep(this.autocomplete, function(v, i) {
                      return offset ? v.indexOf('/') === -1 && re.test(v) : re.test(v);
                     });
      this.tabbed = -1; // ++ below will make this 0 the first time
    }

    if(this.matched.length === 0) return val;
    if(++this.tabbed >= this.matched.length) this.tabbed = 0;
    complete = val.substr(0, this.autocomplete_offset) + this.matched[this.tabbed];
    if(complete.indexOf('/') !== 0 && val.indexOf(' ') === -1) complete +=  ': ';
    if(this.matched.length === 1) this.matched = []; // do not allow more tabbing on one hit

    return complete;
  },
  keydownCallback: function(e) {
    var self = this;
    return function(e) {
      switch(e.keyCode) {
        case 38: // up
          e.preventDefault();
          if(self.history_index == self.history.length) self.initial_value = this.value;
          if(--self.history_index < 0) self.history_index = 0;
          this.value = self.history[self.history_index];
          break;

        case 40: // down
          e.preventDefault();
          if(++self.history_index >= self.history.length) self.history_index = self.history.length;
          this.value = self.history[self.history_index] || self.initial_value || '';
          break;

        case 9: // tab
          e.preventDefault();
          this.value = self.tabbing(this.value);
          break;

        case 13: // return
          if(this.value.length === 0) return e.preventDefault(); // do not send empty commands
          self.history.push(this.value);
          self.history_index = self.history.length;
          break;

        default:
          self.tabbing(false);
          delete self.initial_value;
      }
    };
  },
  init: function(input_selector) {
    var self = this;
    var $input = $(input_selector);

    self.history = [];
    self.history_index = 0;
    self.$input = $input;

    $input.keydown(self.keydownCallback());
    $input.parents('form').submit(function(e) { return self.submit(e); });
    $input.focus();

    $('body').click(function() { $input.focus(); });

    return self;
  }
}); // End Wirc.Chat.Input

$(document).ready(function() {
  BASEURL = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');
  $('#chat_messages').each(function() { setTimeout(function() { Wirc.Chat.init($); }, 100); });
});

})(jQuery);

/*
 * Flash fallback for websocket
 *
if(!('WebSocket' in window)) {
  document.write([
    '<script type="text/javascript" src="' + BASEURL + '/js/swfobject.js"></script>',
    '<script type="text/javascript" src="' + BASEURL + '/js/FABridge.js"></script>',
    '<script type="text/javascript" src="' + BASEURL + '/js/web_socket.js"></script>'
  ].join(''));
}
if(WebSocket.__initialize) {
  // Set URL of your WebSocketMain.swf here:
  WebSocket.__swfLocation = BASEURL + '/js/WebSocketMain.swf';
}
*/
