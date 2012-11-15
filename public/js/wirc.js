var BASEURL = window.location.href;

(function($) {

Structure.registerModule('Wirc', {
  websocket: function(path, callbacks) {
    var url = BASEURL.replace(/^http/, 'ws') + path;
    var websocket = new WebSocket(BASEURL.replace(/^http/, 'ws') + '/socket');
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
  print: function(data) {
    var $previous = this.$messages.find('td.nick').eq(-1).parent();
    var next;

    if(data.timestamp) {
      data.timestamp = new Date(parseInt(data.timestamp, 10));
    }

    if(data.error) {
      next = tmpl('error_message_template', data);
    }
    else {
      next = tmpl('message_template', data);
    }

    this.$messages.append(next);
    this.scrollToBottom();
  },
  scrollToBottom: function() {
    $('html, body').scrollTop($('body').get(0).scrollHeight);
  },
  receiveData: function(e) {
    var data = $.parseJSON(e.data);

    if(window.console) console.log('[websocket] > ' + e.data);

    if(data.error || data.message) {
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
        self.sendData({ cid: self.connection_id, cname: self.conversation_name });
      },
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

    if(window.console) console.log('[Wirc.Chat.setupUI] input.autocomplete');
    self
    .$input
    .attr('autocomplete', 'off')
    .focus()
    .typeahead({
      source: Object.keys(self.autocomplete_commands),
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

    if(window.console) console.log('[Wirc.Chat.setupUI] form.submit');
    self.$input.parents('form').submit(function() {
      self.sendData({ cid: self.connection_id, cname: self.conversation_name, cmd: self.$input.val() });
      self.$input.val('');
      return false;
    });

    self.scrollToBottom();
  },
  listenToScroll: function() {
    var $win = $(window);
    var $table = $('table.table-with-fixed-footer');
    var url = '/?does_not_exist'; //window.location.href;
    var loading = false;
    var page = 1;

    $win.on('scroll', function() {
      if(loading || $win.scrollTop() !== 0) return;
      loading = $('<div class="alert alert-info">Loading previous conversations...</div>');
      page++;
      $table.before(loading);
      $.ajax({
        url: url + (url.indexOf('?') > 0 ? '&page=' : '?page=') + page,
        success: function(data) {
          var $tr = $(data).find('table.table-with-fixed-footer tbody tr');
          if($tr.length) {
            $table.find('tbody').prepend($tr);
            loading.remove();
            loading = false;
            $(window).resize(); // fix fixed table header
          }
          else {
            loading.removeClass('alert-info').text('End of conversation log.');
          }
        }
      });
    });
  },
  start: function($) {
    this.connection_id = $('#messages').attr('data-cid');
    this.conversation_name = $('#messages').attr('data-cname');
    this.$messages = $('#messages');
    this.$input = $('.chat.stick-to-bottom input[type="text"]');
    this.connectToWebSocket();
    this.setupUI();
    this.listenToScroll();
    if(window.console) console.log('[Wirc.Chat.start] ', this);
  }
}); /* End Structure.registerModule('Wirc.Chat') */

$(document).ready(function() {
  BASEURL = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');
  $('#messages').each(function() { setTimeout(function() { Wirc.Chat.start($); }, 100); });
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
