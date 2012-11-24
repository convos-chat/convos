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

Structure.registerModule('Wirc.Chat', {
  autocomplete_commands: {
    '/join': { append: ' #' },
    '/msg': { append: ' ' },
    '/me': { append: ' ' },
    '/nick': { append: ' ' },
    '/part': {}
  },
  formatIrcData: function(data) {
    var me_re = new RegExp("\\b" + this.nick + "\\b");
    var action = data.message.match(/^\u0001ACTION (.*)\u0001$/);

    if(action) data.message = action[1];

    data.nick = data.sender.replace(/!.*/, '');
    data.message = data.message.replace(/</i, '&lt;').replace(/\b(\w{2,5}:\/\/\S+)/g, '<a href="$1" target="_blank">$1</a>');
    data.template = action ? 'action_message_template' : 'message_template';
    data.class_name = data.prefix === this.nick                           ? 'me'
                    : data.message.match(me_re)                           ? 'focus'
                    : $('#chat_messages').find('li:last').hasClass('odd') ? 'even'
                    :                                                       'odd';

    return data;
  },
  print: function(data) {
    // need to calculate at_bottom before appending a new element
    var at_bottom = $(window).scrollTop() + $(window).height() >= $('body').height() - 30;
    var $messages = this.$messages;

    if(data.timestamp) {
      data.timestamp = new Date(parseInt(data.timestamp, 10));
    }

    if(data.status) {
      $('#ws-status').css('color','#33CC33');
    }
    else if(data.new_nick) {
      if(data.old_nick == this.nick) {
        this.nick = data.new_nick;
      }
      $messages.append(tmpl('nick_change_template', data));
    }
    else if(data.message && data.target == this.target) {
      data = this.formatIrcData(data);
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
    if(window.console) console.log('[websocket] > ' + e.data);
    if(data.joined) {
      var $li = $('#channel_list li:last').clone();
      // TODO: Fix a better link
      $li.find('a').text(data.joined);
      $('#channel_list > ul').append($li);
    }
    else {
      this.print(data);
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
        self.$input.attr('disabled',undefined);
        $('#ws-status').css('color','green');
        self.sendData({ cid: self.connection_id, target: self.target });
      },
      onerror: function(e) {
        self.print({ error: e.data });
        self.$input.attr('disabled', 'disabled');
        $('#ws-status').css('color','red');
      },
      onclose: function() {
        self.print({ error: 'Disconnected.' });
        $('#ws-status').css('color','orange');
        self.$input.attr('disabled', 'disabled');
      }
    });
  },
  setupUI: function() {
    var self = this;

    self
      .$input
      .attr('autocomplete', 'off')
      .focus()
      .typeahead({
        source: function() { return Object.keys(self.autocomplete_commands); },
        items: 5,
        matcher: function(item) {
          return item.toLowerCase().indexOf(this.query.toLowerCase()) === 0;
        },
        updater: function(item) {
          if(self.autocomplete_commands[item].append) {
            return item + self.autocomplete_commands[item].append;
          }
          else {
            self.$input.val(item);
            self.$input.parents('form').submit();
            return '';
          }
        }
      });

    self.$input.parents('form').submit(function() {
      self.sendData({ cid: self.connection_id, target: self.target, cmd: self.$input.val() });
      self.$input.val('');
      return false;
    });

    $('body').click(function() { self.$input.focus(); });
    self.scrollToBottom();
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
    self.$messages = $('#chat_messages');
    self.$input = $('#chat_input_field input[type="text"]');
    self.connectToWebSocket();
    self.setupUI();
    self.listenToScroll();

    $.each($('#chat_messages').attr('data-nicks').split(','), function(i, v) {
      v = v.replace(/^\@/, '');
      self.autocomplete_commands[v] = { append: ': ' };
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
