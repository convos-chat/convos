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
    // need to calculate at_bottom before appending a new element
    var at_bottom = $(window).scrollTop() + $(window).height() >= $('body').height() - 30;
    var $messages = this.$messages;

    if(data.timestamp) {
      data.timestamp = new Date(parseInt(data.timestamp, 10));
    }

    data.class_name = $messages.find('li:last').hasClass('even') ? 'odd' : 'even';

    if(data.status) {
      $messages.append(tmpl('server_status_template', data));
    }
    else if(data.nick) {
      this.nick = data.nick;
      $messages.append(tmpl('nick_change_template', data));
    }
    else if(data.message && data.target == this.target) {
      var me_re = new RegExp("\\b" + this.nick + "\\b");
      var tmp;
      data.message = data.message.replace(/</i, '&lt;');
      data.prefix = data.sender.replace(/!.*/, '');
      if(data.prefix === this.nick) data.class_name = 'me';
      else if(data.message.match(me_re)) data.class_name = 'focus';
      data.message = data.message.replace(/\b(\w{2,5}:\/\/\S+)/g, '<a href="$1" target="_blank">$1</a>');
      tmp = data.message.match(/^\u0001 ACTION (.*)/);
      if(tmp) {
        data.message = tmp[1];
        $messages.append(tmpl('action_message_template', data));
      }
      else {
        $messages.append(tmpl('message_template', data));
      }
    }

    if(at_bottom) {
      this.scrollToBottom();
    }
  },
  scrollToBottom: function() {
    $('html, body').scrollTop($('body').height());
  },
  receiveData: function(e) {
    if(window.console) console.log('[websocket] > ' + e.data);
    this.print($.parseJSON(e.data));
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
        self.sendData({ cid: self.connection_id, target: self.target });
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

    self.$input.parents('form').submit(function() {
      self.sendData({ cid: self.connection_id, target: self.target, cmd: self.$input.val() });
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
    this.nick = $('#messages').attr('data-nick');
    this.target = $('#messages').attr('data-target');
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
