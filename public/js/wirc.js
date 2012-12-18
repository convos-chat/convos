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
    if(!window.webkitNotifications) return;
    if(window.webkitNotifications.checkPermission() != 0) return;
    return window.webkitNotifications;
  },
  show: function(icon, title, msg) {
    if(!this.notifier = this.init()) return;
    var notification = this.notifier.createNotification(icon || '', title, msg || '');
    notification.show();
  }
}); // End Wirc.Notify

Structure.registerModule('Wirc.Chat', {
  autocomplete_commands: [
    '/join #',
    '/msg ',
    '/me ',
    '/nick ',
    '/part '
  ],
  formatIrcData: function(data) {
    var action = data.message.match(/^\u0001ACTION (.*)\u0001$/);

    if(action) data.message = action[1];
    data.message = data.message.replace(/</i, '&lt;').replace(/\b(\w{2,5}:\/\/\S+)/g, '<a href="$1" target="_blank">$1</a>');
    data.template = action ? 'action_message_template' : 'message_template';
    data.class_name = data.nick === this.nick                           ? 'me'
                    : data.highlight                           ? 'focus'
                    : $('#chat_messages').find('li:last').hasClass('odd') ? 'even'
                    :                                                       'odd';

    return data;
  },
  print: function(data) {
    // need to calculate at_bottom before appending a new element
    var at_bottom = $(window).scrollTop() + $(window).height() >= $('body').height() - 30;
    var $messages = this.$messages;

    if(data.timestamp) {
      data.timestamp = new Date(parseInt(data.timestamp*1000, 10));
    }

    if(data.status) {
      if(data.status == this.status) return; // do not want duplicate status messages
      if(data.message) $messages.append(tmpl('server_status_template', data));
      this.status = data.status;
    }
    else if(data.new_nick) {
      if(data.old_nick == this.nick) {
        this.nick = data.new_nick;
      }
      $messages.append(tmpl('nick_change_template', data));
    }
    else if(data.message && data.target == this.target || data.nick == this.target) {
      data = this.formatIrcData(data);
      var index = $.inArray(data.nick + ': ', this.autocomplete_commands);
      if(index != -1) { this.autocomplete_commands.splice(index,1); }
      this.autocomplete_commands.unshift(data.nick + ': ');
      $messages.append(tmpl(data.template, data));
    }

    if(at_bottom) {
      this.scrollToBottom();
    }
  },
  scrollToBottom: function() {
    $('html, body').scrollTop($('body').height());
  },
  receiveData: function(e) {
    var data = $.parseJSON(e.data);
    var channel_id;

    if(window.console) console.log('[websocket] > ' + e.data);

    data.highlight = data.message && data.message.match("\\b" + this.nick + "\\b") ? 1 : 0;
    
    if (data.highlight) {
      Wirc.Notifier.show('', 'New mention by ' + data.nick + ' in ' + data.target, data.message);
    }
    else if (data.target === this.nick) {
      Wirc.Notifier.show('', 'New message from ' + data.nick, data.message);
    }

    if(data.joined) {
      data.channel_id = data.joined.replace(/\W/g, '');
      var $channel = $('#target_' + data.cid + '_' + data.channel_id);
      if(!$channel.length) {
        $(tmpl('new_channel_template', data)).insertAfter('#connection_list_' + data.cid + ' .channel:last');
      }
      if(data.nick !== this.nick && data.joined === this.target) {
        this.$messages.append( $(tmpl('nick_joined_template', data)) );
      }
    }
    else if(data.parted) {
      channel_id = data.parted.replace(/\W/g, '');
      $('#target_' + data.cid + '_' + channel_id).remove();
    }
    else if(data.target && this.target != this.nick && this.target != data.target && data.target === this.nick) {
      var $conversation=$('#target_' + data.cid + '_' + data.nick);
      if(!$conversation.length) {
        $(tmpl('new_conversation_template',data)).appendTo('#connection_list_' + data.cid);
      }
    }
    else {
      this.print(data);
    }

    if(data.cid == this.connection_id && data.target == this.target) {

      if(!self.hasfocus && !this.oldTitle) {
        this.oldTitle=document.title;
        document.title = 'New message in ' + this.target;
      }
    }
    else if(data.target) {
      channel_id = data.target.replace(/\W/g, '');
      
      var $badge=$(['#target', data.cid, channel_id].join('_')+' .badge')
      if(data.highlight) { $badge.addClass('badge-important') }
      $badge.text(parseInt($badge.text())+1).show();
    }
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
  connectToWebSocket: function() {
    var self = this;
    self.websocket = Wirc.websocket('/socket', {
      onmessage: self.receiveData,
      onopen: function function_name (argument) {
        self.$input.removeAttr('disabled').css({ background: '#fff' }).attr('placeholder','Write a message to reply');
        self.$input.focus();
        self.sendData({ cid: self.connection_id, target: self.target });
      },
      onerror: function(e) {
        self.$input.attr('disabled', 'disabled').css({ background: '#fdd' }).attr('placeholder',e)
      },
      onclose: function() {
        self.$input.attr('disabled', 'disabled').css({ background: '#eee' }).attr('placeholder','Reconnecting...');
      }
    });
  },
  setupUI: function() {
    var self = this;
    var $input = self.$input;

    $input.attr('disabled', 'disabled').css({ background: '#eee' }).attr('placeholder','Connecting...');
    $input.parents('form').submit(function() {
      self.sendData({ cid: self.connection_id, target: self.target, cmd: $input.val() });
      $input.val('');
      return false;
    });

    $input.keydown(function(e) {
      switch(e.keyCode) {
        case 38: // up
          e.preventDefault();
          if(self.history_index == self.history.length) this.initial_value = this.value;
          if(--self.history_index < 0) self.history_index = 0;
          $input.val(self.history[self.history_index]);
          break;

        case 40: // down
          e.preventDefault();
          if(++self.history_index >= self.history.length) self.history_index = self.history.length;
          $input.val(self.history[self.history_index] || this.initial_value || '');
          break;

        case 9: // tab
          e.preventDefault();

          if(typeof this.tabbed === "undefined") {
            var v = this.value;
            this.offset = v.lastIndexOf(' ') + 1;
            if(this.offset > 0 && v.substr(this.offset).search(/^[a-z_]/i) !== 0) return;
            this.initial_value = v;
            this.partial_re = new RegExp('^' + v.substr(this.offset));
            this.tabbed = 0;
          }

          var re = this.partial_re;
          var matched = $.grep(self.autocomplete_commands, function(v) { return re.test(v); });
          if(matched.length === 0) return;
          if(++this.tabbed >= matched.length) this.tabbed = 0;
          if(this.offset) {
            this.value = this.value.substr(0, this.offset) + matched[this.tabbed].replace(/:\s*$/,' ');
          } else {  this.value = matched[this.tabbed];}
          break;

        case 13: // return
          if(this.value.length === 0) return e.preventDefault();
          if(window.webkitNotifications && window.webkitNotifications.checkPermission()) { window.webkitNotifications.requestPermission() }
          self.history.push(this.value);
          self.history_index = self.history.length;
          break;

        default:
          delete this.tabbed;
          delete this.initial_value;
      }
    });

    $('body').click(function() { $input.focus(); });
    self.scrollToBottom();
    $(window).blur( function() { self.hasfocus = false; });

     $(window).focus( function() {
       self.hasfocus = true;
       if(self.oldTitle) {
         document.title=self.oldTitle;
         self.oldTitle=null;
       }
     });
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
  start: function($) {
    var self = this;
    self.connection_id = $('#chat_messages').attr('data-cid');
    self.nick = $('#chat_messages').attr('data-nick');
    self.target = $('#chat_messages').attr('data-target');
    self.history = [];
    self.history_index = 0;
    self.unread = {};
    self.$messages = $('#chat_messages');
    self.$input = $('#chat_input_field input[type="text"]');
    self.connectToWebSocket();
    self.setupUI();
    self.listenToScroll();

    $.each($('#chat_messages').attr('data-nicks').split(','), function(i, v) {
      v = v.replace(/^\@/, '');
      self.autocomplete_commands.unshift(v+': ');
    });

    if(window.console) console.log('[Wirc.Chat.start] ', this);
  }
}); /* End Structure.registerModule('Wirc.Chat') */

$(document).ready(function() {
  BASEURL = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');
  $('#chat_messages').each(function() { setTimeout(function() { Wirc.Chat.start($); }, 100); });
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
