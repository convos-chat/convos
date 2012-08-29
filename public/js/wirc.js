(function($) {

Structure.registerModule('Wirc', {
  websocket: function(path, callbacks) {
    var url = BASEURL.replace(/^http/, 'ws') + path;
    var websocket = new WebSocket(BASEURL.replace(/^http/, 'ws') + '/socket');
    window.console && console.log('[websocket] ' + url);
    $.each(callbacks, function(name, callback) { websocket[name] = callback });
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
  print: function(data) {
    var $previous = this.$messages.find('li .sender').eq(-1).parent();
    var next;

    if(data.error) {
      next = tmpl('tmpl_li_error', data);
    }
    else if($previous.find('.sender a').text() == data.sender) {
      next = tmpl('tmpl_li_message', { message: data.message, timestamp: data.timestamp });
    }
    else {
      next = tmpl('tmpl_li_message', data);
    }

    this.$messages.append(next);
    this.scrollToBottom();
  },
  scrollToBottom: function() {
    this.$messages.scrollTop(this.$messages.get(0).scrollHeight - this.$messages.height());
  },
  receiveData: function(e) {
    var data = $.parseJSON(e.data);

    window.console && console.log('[websocket] > ' + e.data);

    if(data.error || data.message) {
      this.print(data);
    }
  },
  sendData: function(data) {
    // TODO: Figure out if JSON.stringify() works in other browsers than chrome
    try {
      this.websocket.send(JSON.stringify(data));
      window.console && console.log('[websocket] < ' + JSON.stringify(data));
    } catch(e) {
      window.console && console.log('[websocket] ! ' + e);
      this.print({ error: e });
    };
  },
  connectToWebSocket: function() {
    var self = this;
    self.websocket = Wirc.websocket('/socket', {
      onmessage: self.receiveData,
      onerror: function(e) {
        self.print({ error: e.data });
        self.$input.attr('disabled', 'disabled');
      },
      onclose: function() {
        self.print({ error: 'Disconnected.' });
        self.$input.attr('disabled', 'disabled');
      }
    });
  },
  setupUI: function() {
    var self = this;

    window.console && console.log('[Wirc.Chat.setupUI] input.autocomplete');
    self
    .$input
    .attr('autocomplete', 'off')
    .focus()
    .typeahead({
      source: Object.keys(self.autocomplete_commands),
      items: 5,
      matcher: function(item) {
        return item.toLowerCase().indexOf(this.query.toLowerCase()) == 0;
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

    window.console && console.log('[Wirc.Chat.setupUI] form.submit');
    self.$input.parents('form').submit(function() {
      self.sendData({ command: self.$input.val(), target: self.target });
      self.$input.val('');
      return false;
    });

    self.scrollToBottom();
  },
  start: function($) {
    this.server = unescape(window.location.href.split('/')[4] || '');
    this.target = unescape(window.location.href.split('/')[5] || '');
    this.$messages = $('#messages');
    this.$input = $('#message input[type="text"]');
    this.connectToWebSocket();
    this.setupUI();
    window.console && console.log('[Wirc.Chat.start] ', this);
  }
}); // End Wirc.Chat

jQuery(document).ready(function() {
  BASEURL = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');
  if($('#messages').length) Wirc.Chat.start($);
});

})(jQuery);

BASEURL = window.location.href;

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
