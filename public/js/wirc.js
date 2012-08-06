var BASEURL = window.location.href;

(function($) {
  var commands = {
    '/join': { append: ' #' },
    '/msg': { append: ' ' },
    '/me': { append: ' ' },
    '/nick': { append: ' ' },
    '/part': {}
  };

  $(document).ready(function() {
    BASEURL = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');

    window.console && console.log('Connecting to ' + BASEURL.replace(/^http/, 'ws') + '/socket ...');
    var chat = new WebSocket(BASEURL.replace(/^http/, 'ws') + '/socket');
    var ui = {
      $input: $('#message input[type="text"]'),
      history_index: 0,
      history: []
    };

    chat.onmessage = function(e) {
      var data = typeof e.data == 'object' ? e.data : $.parseJSON(e.data);
      var $li = $('#messages li:first').clone();

      $li.find('span.sender:first > a').text(data.sender);
      $li.find('span.sender:first > a').attr('href', data.sender); // TODO
      $li.find('span.message:first').text(data.message);
      $('#messages').append($li);
    };
    chat.end = function() {
        ui.print({ sender: '&client', message: 'Disconnected. <a href="">Reconnect?</a>' });
        ui.$input.attr('disabled', 'disabled');
    };

    ui.$input.attr('autocomplete', 'off');
    ui.$input.parents('form').submit(function() {
      try {
        // TODO: Figure out if JSON.stringify() works in other browsers than chrome
        chat.send(JSON.stringify({ command: ui.$input.val() }));
        window.console && console.log('send: ' + ui.$input.val());
      } catch(e) {
        window.console && console.log('Could not send to websocket: ' + e);
        chat.onmessage({ data: { sender: 'internal', message: e } });
      };
      ui.$input.val('');
      return false;
    });

    ui.$input.typeahead({
      source: Object.keys(commands),
      items: 5,
      matcher: function(item) {
        return item.toLowerCase().indexOf(this.query.toLowerCase()) == 0;
      },
      updater: function(item) {
        if(commands[item].append) {
          return item + commands[item].append;
        }
        else {
          ui.$input.val(item);
          ui.$input.parents('form').submit();
          return '';
        }
      }
    });
  });
})(jQuery);

/*
// want to lazy load javascripts to prevent loading indicator
(function(d){
  var js, id = 'facebook-jssdk'; if (d.getElementById(id)) {return;}
  js = d.createElement('script'); js.id = id; js.async = true;
  js.src = "//connect.facebook.net/en_US/all.js";
  d.getElementsByTagName('head')[0].appendChild(js);
}(document));
*/

/*
 * flash fallback
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
