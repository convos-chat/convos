;(function($) {
  var $input, $messages, $win, chat_ws, current_target, history_offset, nick;
  var nicks = new sortedSet();
  var commands = [
    '/help',
    '/join #',
    '/query ',
    '/msg ',
    '/me ',
    '/nick ',
    '/close',
    '/part ',
    '/names ',
    '/topic ',
    '/reconnect',
    '/whois '
  ];

  // same as id_as() helper in mojo
  var id_as = function(str) {
    return $.map(str.split(':00'), function(s, i) {
      return s.replace(/:(\w\w)/g, function(match, p1) {
        return String.fromCharCode(parseInt('0x' + p1, 16));
      });
    });
  };

  var conversationLoaded = function(e) {
    current_target = $messages.attr('id').replace(/^conversation_/, '');
    history_offset = parseFloat($messages.attr('data-offset') || 0);
    nick = $('.messages ul').attr('data-nick') || '';
    nicks = new sortedSet();

    if(/:23/.exec(current_target)) { // is channel
      sendMessage('/names');
      sendMessage('/topic');
    }
    if(e) {
      reloadConversationList();
      reloadNotificationList();
    }

    drawUI();
  };

  var drawUI = function() {
    var $conversation_list = $('div.conversation-list li').hide();
    var $conversation_list_button = $('nav a.conversation-list').hide();
    var available_width = $('nav').width() - $('nav .right').outerWidth() - $('nav a.settings').outerWidth();
    var used_width = 0;
    var left;

    $('nav .conversation-list a').each(function(i) {
      used_width += $(this).show().outerWidth();
      if(used_width < available_width) return;
      $conversation_list.eq(i).show();
      $(this).hide();
    });

    if(used_width >= available_width) {
      $conversation_list_button.show();
      left = $conversation_list_button.offset().left - 320 + 22;
      left = left < 6 ? 6 : left;
      $conversation_list.closest('div').css('left', left + 'px');
    }
    else {
      $conversation_list_button.trigger('toggle_hide');
    }

    if($win.data('at_bottom')) {
      $win.scrollToBottom();
    }
  };

  var getHistory = function() {
    if(!history_offset || $win.scrollTop() !== 0) return;
    $.get(location.href, { before: history_offset }, function(data) {
      var $data = $(data);
      var $heigth_from = $(document).data('heigth_from');
      if($data.children('li').length === 0) return;
      var height_before_prepend = $heigth_from.height();
      $messages.prepend($data.children('li'));
      $win.scrollTop($heigth_from.height() - height_before_prepend);
      console.log(height_before_prepend);
      history_offset = $data.attr('data-offset');
    });
    history_offset = 0;
  };

  var initInputField = function() {
    var complete, val, offset, re;
    var history = { index: 0, list: [], current: '' };
    $input = $('footer form input');

    $win.focus(function() {
      if($win.data('at_bottom')) $input.focus();
    });
    $('body, input').bind('keydown', 'shift+return', function(e) {
      e.preventDefault();
      $win.scrollToBottom();
      $input.focus();
    });
    $input.bind('keydown', function(e) {
      if(e.keyCode !== 9) complete = false; // not tab
    });
    $input.bind('keydown', 'tab', function(e) {
      val = $input.val();
      offset = val.lastIndexOf(' ') + 1;
      re = new RegExp('^' + RegExp.escape(val.substr(offset)), 'i');
      complete = complete || {
        i: 0,
        prefix: val.substr(0, offset),
        list: $.map(
          $.grep(
            nicks.revrange(0, -1).concat(commands),
            function(v, i) {
              return offset && v.indexOf('/') === 0 ? false : re.test(v) ? true : false;
            }
          ),
          function(v, i) {
            return offset || v.indexOf('/') === 0 ? v : v + ': ';
          }
        ).concat(val.substr(offset))
      };

      $input.val(complete.prefix + complete.list[complete.i++]);
      if(complete.i == complete.list.length) complete.i = 0;
      return false;
    });
    $input.bind('keydown', 'up', function(e) {
      e.preventDefault();
      if(history.index == 0) return;
      if(history.index == history.list.length) history.current = $input.val();
      $input.val(history.list[--history.index]);
    });
    $input.bind('keydown', 'down', function(e) {
      e.preventDefault();
      if(++history.index == history.list.length) return $input.val(history.current);
      if(history.index > history.list.length) return history.index = history.list.length;
      $input.val(history.list[history.index]);
    });
    $input.closest('form').submit(function(e) {
      e.preventDefault();
      var val = $input.val();
      if(val.length === 0) return false;
      sendMessage(val);
      history.list.push(val);
      history.index = history.list.length;
      $input.val('');
    });
  };

  var initNickList = function($data) {
    var senders = {};

    $('.messages li[data-sender]').each(function(i) {
      senders[$(this).attr('data-sender')] = i;
    });

    nicks.clear();
    $data.find('[data-nick]').each(function() {
      var n = $(this).attr('data-nick');
      if(n === nick) return;
      nicks.add(senders[n] || 1, n);
    });
  }

  var receiveMessage = function(e) {
    var $data = $(e.data);
    var cid_target = id_as($data.attr('data-target'));
    var cid_target_selector = targetToSelector($data.attr('data-target'));
    var at_bottom = $win.data('at_bottom');
    var current = $('#conversation_' + cid_target_selector).length ? true : false;

    $input.removeClass('sending');

    if(typeof cid_target[1] === 'undefined') cid_target[1] = ''; // server messages
    if($data.hasClass('add-conversation')) return location.href = $.url_for(cid_target.join('/'));
    if($data.hasClass('remove-conversation') && current) return location.href = $.url_for('/');
    if($data.hasClass('remove-conversation')) reloadConversationList();
    if($data.hasClass('nicks')) initNickList($data);
    if($data.hasClass('nick-joined')) nicks.add(0, $data.attr('data-nick'));
    if($data.hasClass('nick-parted')) nicks.rem($data.attr('data.nick'));
    if($data.attr('data-sender')) nicks.add(new Date().getTime(), $data.attr('data-sender'))
    if(current) $messages.append($data.fadeIn('fast'));

    if($data.hasClass('highlight')) {
      var sender = $data.attr('data-sender');
      var what = cid_target[1].indexOf('#') === 0 ? 'mentioned you in ' + cid_target[1] : 'sent you a message';
      window.notify([sender, what].join(' '), $data.find('.content').text(), '');
      reloadNotificationList();
    }
    if(at_bottom) {
      $win.scrollToBottom();
      $data.find('img').one('load', function() { $win.scrollToBottom() });
    }
  };

  var reloadConversationList = function(e) {
    $.get($.url_for('conversations'), function(data) {
      $('ul.conversation-list').replaceWith(data);
      drawUI();
    });
  };

  var reloadNotificationList = function(e) {
    var $notification_list = $('div.notification-list');
    var $n_notifications = $('a.notification-list');
    var n;

    $.get($.url_for('notifications'), function(data) {
      $notification_list.html(data);
      n = parseInt($notification_list.children('ul').attr('data-notifications'), 10);
      $n_notifications.children('b').text(n);
      if($notification_list.find('li').length) $n_notifications.removeClass('hidden');
      $n_notifications[n ? 'addClass' : 'removeClass']('alert');
    });
  };

  var sendMessage = function(message) {
    var $message = $('<div data-target="' + current_target + '"></div>').text(message);
    chat_ws.send($message.prop('outerHTML'));
    $input.addClass('sending');
  };

  var targetToSelector = function(target) {
    if(target === 'any') target = current_target;
    return target.replace(/:/g, '\\:');
  }

  $(document).ready(function() {
    $messages = $('.messages ul:first');
    $win = $(window);

    if($messages.length === 0) return; // not on chat page

    $('nav a.help').click(function(e) { sendMessage('/help'); $(document).click(); return false; })
    $win.on('scroll', getHistory).on('resize', drawUI);
    chat_ws = $.ws($.url_for('socket').replace(/^http/, 'ws'));
    chat_ws.on('message', receiveMessage);
    initInputField();

    $(document).on('pjax:timeout', function(e) { e.preventDefault(); });
    $(document).pjax('ul.conversation-list a', $messages);
    $(document).pjax('ul.notification-list a', $messages);
    $messages.on('pjax:end', conversationLoaded);
  });

  $(document).on('completely_ready', function() {
    if(location.href.indexOf('after=') === -1) {
      $input.focus();
      $win.data('at_bottom', true); // required before drawUI()
    }
    conversationLoaded();
  });

})(jQuery);