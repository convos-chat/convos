;(function($) {
  window.convos = window.convos || {}

  var connect = function() {
    var socket_url = $('body').attr('data-socket-url');
    convos.socket = new ReconnectingWebSocket({ url: socket_url, ping_protocol: [ 'PING', 'PONG' ] });
    convos.socket.onmessage = receiveMessage;
    convos.socket.onpong = function(e) { convos.input.attr('placeholder', 'What\'s on your mind ' + convos.current.nick + '?'); };
    convos.socket.onclose = function() { convos.input.addClass('disabled'); };
    convos.socket.onopen = function(e) {
      convos.input.removeClass('disabled');
      if (e.reconnected) $.pjax({ url: location.href, container: 'div.messages', fragment: 'div.messages'});
    };
  };

  var messageFailed = function($message) {
    var uuid = $message.attr('id');
    var $actions = $('<h3>Could not send message</h3><span class="actions"><button>Resend</button> <button>&times;</button></span>');
    var $pending = $('div.messages ul').find('#' + uuid).filter('.message-pending')

    $actions.find('button:first').on('click', function() {
      convos.socket.buffer = []; // need to clear buffer when resending messages
      convos.send($(this).parents('li').find('.content').text());
      $(this).parents('li').remove();
    });
    $actions.find('button:last').on('click', function() {
      $(this).parents('li').remove();
    });

    $pending.addClass('message-error').removeClass('message-pending').prepend($actions);
  };

  var receiveHighlightMessage = function($message, to_current) {
    var body = $message.find('.content').text() || '...';
    var icon = $message.find('img').attr('src') || $.url_for('/images/icon-48.png');
    var sender = $message.data('sender');
    var what = /^[#&]/.test($message.data('target')) ? 'mentioned you in ' + $message.data('target') : 'sent you a message';
    var notified = $.notify([sender, what].join(' '), body, icon);

    // Mark message as read if $message is sent to current conversation
    $.get($.url_for('/chat/notifications'), $.noCache({ nid: !notified && to_current ? 0 : '' }), function(data) {
      var $data = $(data);
      $('nav a.notifications b').text($data.find('ul').data('notifications') || '');
      $('.notification-list ul').html($data.find('li'));
    });
  };

  var receiveMessage = function(e) {
    var $message = $(e.data);
    var uuid = $message.attr('id');
    var url = $.url_for($message.attr('data-network'), encodeURIComponent($message.attr('data-target')));
    var to_current = toCurrent($message);

    if ($('#' + uuid).length) {
      if ($message.hasClass('error')) {
        messageFailed($message);
      }
      else {
        $('#' + uuid).remove();
      }
    }

    if ($message.hasClass('highlight')) {
      receiveHighlightMessage($message, to_current);
    }

    if ($message.hasClass('remove-conversation')) {
      $('nav ul.conversations a').slice(1).each(function() {
        if(this.href.indexOf(url) >= 0) return;
        $(this).click();
        return false;
      });
    }
    else if ($message.hasClass('add-conversation')) {
      $.pjax({ url: url, container: 'div.messages', fragment: 'div.messages'})
    }
    else if (to_current) {
      $message.addToMessages();
    }
    else if ($message.hasClass('message')) {
      var $unread = $('nav ul.conversations').find('a[href="' + url + '"]').children('b');
      $unread.text(parseInt($unread.html() || 0) + 1);
    }

    if (convos.at_bottom) $(window).scrollTo('bottom');
  };

  var toCurrent = function($e) {
    if ($e.data('target') == '') return true;
    if ($e.data('network') != convos.current.network) return false;
    if ($e.data('target') != convos.current.target) return false;
    return true;
  };

  convos.send = function(message, attr) {
    if (!convos.socket) connect();
    if (message.length == 0) return;
    attr = attr || {};
    $.each(['network', 'state', 'target'], function(k, i) { attr["data-" + k] = attr["data-" + k] || convos.current[k]; });
    attr['data-network'] = convos.current.network;
    attr['data-state'] = convos.current.state;
    attr['data-target'] = convos.current.target;
    attr['id'] = window.guid();
    if (!message.match('^\/') || attr.pending_status) {
      var $pendingMessage = $('<li class="message-pending"><div class="content"></div></li>').attr(attr);
      $pendingMessage.find('.content').text(message);
      setTimeout(function() { messageFailed($pendingMessage); }, 10000);
      $pendingMessage.addToMessages();
    }
    convos.socket.send($('<div/>').attr(attr).text(message).prop('outerHTML'));
    if (attr['data-history']) convos.addInputHistory(message);
    if (convos.at_bottom) $(window).scrollTo('bottom');
  };
})(jQuery);
