;(function($) {
  window.convos = window.convos || {};

  var socket;
  var connect = function() {
    var socketUrl = $('body').attr('data-socket-url');
    socket = new ReconnectingWebSocket({ url: socketUrl, ping_protocol: [ 'PING', 'PONG' ] });
    socket.onmessage = receiveMessage;
    socket.onpong = enableInput;
    socket.onclose = function() { convos.input.addClass('disabled'); };
    socket.onopen = function(e) {
      enableInput();
      convos.current.end_time = $('li.message[data-timestamp]:last').data('timestamp');
      convos.getNewerMessages();
    };
    convos.send.socket = socket;
  };

  var addPendingMessage = function(message, attr) {
    var $pending = $('<li><h3>' + convos.current.nick + '</h3><div class="content">' + message + '</div></li>').attr(attr);
    $pending.addClass('message pending').data('sender', convos.current.nick).addToMessages();
    setTimeout(function() { messageFailed(attr.id); }, 10000);
    if (convos.at_bottom) $(window).scrollTo('bottom');
  };

  var enableInput = function() {
    idleTimer();
    convos.input.attr('placeholder', 'What is on your mind, ' + convos.current.nick + '?');
    convos.input.removeClass('disabled');
  };

  var idleTimer = function() {
    if (idleTimer.t) clearTimeout(idleTimer.t);
    if (!convos.current.target) convos.getNewerMessages(); // make sure we have the newest server messages on register
    idleTimer.t = setTimeout(function() { convos.emit('idle') }, 1500);
  };

  var messageFailed = function(id, description) {
    var $pending = $('#' + id);
    var $actions = $('<span class="actions"><button>Resend</button> <button>&times;</button></span>');

    if (!$pending.hasClass('pending')) return; // let's not mark messages as fail on timeout

    $actions.find('button:first').on('click', function() {
      socket.buffer = []; // need to clear buffer when resending messages
      convos.send($(this).parents('li').find('.content').text());
      $(this).closest('li').remove();
    });
    $actions.find('button:last').on('click', function() {
      $(this).closest('li').remove();
    });

    $pending.addClass('error').removeClass('hidden pending');
    $pending.prepend($actions);
  };

  var receiveHighlightMessage = function($message) {
    var body = $message.find('.content').text() || '...';
    var icon = $message.find('img').attr('src') || $.url_for('/images/icon-48.png');
    var sender = $message.data('sender');
    var what = /^[#&]/.test($message.data('target')) ? 'mentioned you in ' + $message.data('target') : 'sent you a message';
    var notified = $.notify([sender, what].join(' '), body, icon);

    // Mark message as read if $message is sent to current conversation
    $.get($.url_for('/chat/notifications'), $.noCache({ nid: !notified && $message.data('to_current') ? 0 : '' }), function(data) {
      var $data = $(data);
      $('nav a.notifications b').text($data.find('ul').data('notifications') || '');
      $('.notification-list ul').html($data.find('li'));
    });
  };

  var receiveMessage = function(e) {
    var $message = $(e.data);
    var event_name = $message.attr('data-event') || 'message';
    var action = $message.attr('class').match(/^(nick|conversation)-(\w+)/);
    var event_args = $message.attr('data-args');

    idleTimer();
    toCurrent($message);

    if ($message.hasClass('error')) {
      messageFailed($message.attr('id'));
    }
    else {
      $('#' + $message.attr('id')).remove();
    }

    if ($message.hasClass('highlight')) receiveHighlightMessage($message);
    if (action && convos[action[1] + 's']) convos[action[1] + 's'][action[2]]($message);

    if ($message.data('to_current')) {
      if ($message.attr('data-state')) convos.current.state = $message.attr('data-state');
      $message.addToMessages();
    }
    else if ($message.hasClass('message')) {
      receiveOtherMessage($message);
    }

    if (convos.at_bottom) $(window).scrollTo('bottom');
    convos.emit.apply(this, [event_name].concat(event_args ? $.parseJSON($('<textarea />').html(event_args).text()) : [$message]));
  };

  var receiveOtherMessage = function($message) {
    var url = $.url_for($message.attr('data-network'), encodeURIComponent($message.attr('data-target')));
    var $a = $('nav ul.conversations').find('a[href="' + url + '"]');
    var $unread = $a.children('b');
    var n = parseInt($unread.html() || 0) + 1;
    $unread.text(n > 99 ? '99+' : n);
    if ($message.hasClass('highlight')) $a.addClass('mention');
  };

  var toCurrent = function($e) {
    if ($e.data('network') == convos.current.network && $e.data('target') == convos.current.target) $e.data('to_current', true);
    if ($e.data('network') == convos.current.network && $e.data('target') === '') $e.data('to_current', true);
    if ($e.data('network') === '' && $e.data('target') === '') $e.data('to_current', true);
  };

  convos.send = function(message, attr) {
    if (!socket) connect();
    if (message.length === 0) return socket.send('PING');

    attr = attr || {};
    attr.class = message.match('^\/') ? 'hidden' : '';
    attr.id = window.guid();
    $.each(['network', 'state', 'target'], function(i) { attr["data-" + this] = attr["data-" + this] || convos.current[this]; });
    var encodedMsg = message.replace(/[\u00A0-\u9999<>\&]/gim, function(i) {
        return '&#' + i.charCodeAt(0) + ';';
    });

    socket.send($('<div/>').attr(attr).text(encodedMsg).prop('outerHTML'));
    if (attr['data-history']) convos.addInputHistory(message);
    if (!message.match(/^\//)) addPendingMessage(message, attr);
  };
})(jQuery);
