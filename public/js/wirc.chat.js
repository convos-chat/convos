;(function($) {
  var $input, $nick_list, $win, chat_ws, current_target, disable_swipe, nick;
  var $messages = $('does-not-exist-yet');
  var $ask_for_notifications = $('<li class="notice"><div class="question">Do you want notifications? <a href="//yes" class="button yes">Yes</a> <a href="//no" class="button confirm">No</a></div></li>');
  var nicks = new sortedSet();
  var conversation_list = [];
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

  // override original method with a filter
  nicks.add = function(score, member) {
    if(member !== nick) this.set[member] = score;
    return this;
  };

  // same as id_as() helper in mojo
  var id_as = function(str) {
    return $.map(str.split(':00'), function(s, i) {
      return s.replace(/:(\w\w)/g, function(match, p1) {
        return String.fromCharCode(parseInt('0x' + p1, 16));
      });
    });
  };

  var appendToMessages = function($data) {
    var $previous = $messages.children('li:last');
    var last_nick = $previous.attr('data-sender') || '';

    if($data.hasClass('message') && $previous.hasClass('message')) {
      if(last_nick == $data.attr('data-sender')) {
        $data.addClass('same-nick').children('h3, .avatar, .timestamp').remove();
      }
    }

    $messages.append($data.fadeIn('fast'));
  };

  var conversationLoaded = function() {
    var old_target = current_target;
    $messages = $('section.messages ul');
    conversation_list = $('ul.conversation-list a').map(function() { return $(this).text(); }).get();
    current_target = $messages.attr('id').replace(/^conversation_/, '');
    nick = $messages.attr('data-nick') || '';

    $messages.start_time = parseFloat($messages.attr('data-start-time') || 0);
    $('a.conversation-list').trigger('deactivate');
    $('a.notification-list').trigger('deactivate');
    if($win.smallScreen()) $('div.nick-list').animate({ right: '-180px' });

    if(/:23/.exec(current_target)) { // :23 = # = is a channel
      sendMessage('/names');
      sendMessage('/topic');
    }
    if(old_target && old_target != current_target) {
      reloadConversationList({});
    }

    if(location.href.indexOf('from=') > 0) { // link from notification list
      $messages.end_time = parseFloat($messages.attr('data-end-time') || 0);
      $win.scrollTo(0);
      reloadNotificationList();
    }
    else {
      $input.focus();
      $win.data('at_bottom', true); // required before drawUI() and scrollTo('bottom')
    }

    console.log({ at_bottom: $win.data('at_bottom'), current_target: current_target, nick: nick });
    $('body').loadingIndicator('hide');
    getMessages();
    drawUI();
    nicks.clear();
    nickList($('<div/>'));
  };

  var drawUI = function() {
    var $conversation_list = $('div.conversation-list li').hide();
    var $conversation_list_button = $('a.conversation-list').hide();
    var available_width = $('nav').width() - $('nav .right').outerWidth() - $('nav a.settings').outerWidth();
    var used_width = 0;
    var left;

    disable_swipe = $win.smallScreen() ? false : true;
    $nick_list.css({ right: disable_swipe ? 0 : '-180px' });

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
      $conversation_list_button.trigger('deactivate');
    }

    if($win.data('at_bottom')) {
      $win.scrollTo('bottom');
    }
  };

  var getMessages = function() {
    if($messages.start_time && $win.scrollTop() == 0) {
      var end_time = $messages.end_time;
      $.get(location.href.replace(/\?.*/, ''), { to: $messages.start_time }, function(data) {
        var $data = $(data);
        var $li = $data.children('li:lt(-1)');
        var height_before_prepend = $(document).data('heigth_from').height();
        $messages.end_time = end_time;
        if(!$li.length) return;
        $messages.start_time = parseFloat($data.attr('data-start-time'));
        $messages.prepend($li);
        $win.scrollTop($(document).data('heigth_from').height() - height_before_prepend);
      });
      $messages.start_time = $messages.end_time = 0;
    }
    else if($messages.end_time && $win.data('at_bottom')) {
      var start_time = $messages.start_time;
      $.get(location.href.replace(/\?.*/, ''), { from: $messages.end_time }, function(data) {
        var $data = $(data);
        var $li = $data.children('li:gt(0)');
        $messages.start_time = start_time;
        if(!$li.length) return;
        $messages.end_time = parseFloat($data.attr('data-end-time'));
        $li.each(function() { appendToMessages($(this)); });
      });
      $messages.start_time = $messages.end_time = 0;
    }
  };

  var initInputField = function() {
    var complete, val, offset, re;
    var history = { index: 0, list: [], current: '' };
    $input = $('footer form input');

    $('body, input').bind('keydown', 'shift+return', function(e) {
      e.preventDefault();
      $('a[data-toggle]').trigger('deactivate');
      if(document.activeElement == $input.get(0)) {
        var $a = $('nav .conversation-list a');
        $a.eq($a.length > 1 ? 1 : 0).focus();
      }
      else {
        $input.focus();
      }
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
            nicks.revrange(0, -1).concat(conversation_list).concat(commands).unique(),
            function(v, i) {
              return offset && v.indexOf('/') === 0 ? false : re.test(v) ? true : false;
            }
          ),
          function(v, i) {
            return offset ? v + ' ' : v.indexOf('/') === 0 ? v : v + ': ';
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

  var initNickList = function() {
    $nick_list.addClass('nanoscroller').wrapInner('<div class="content"/>').nanoScroller({
      preventPageScrolling: true
    });
  };

  var initNotifications = function() {
    if(Notification.permission === 'granted') return;
    if(Notification.permission === 'unsupported') return;
    if(Notification.permission === 'denied') return;

    $ask_for_notifications.find('a.button.yes').click(function() {
      Notification.requestPermission(function(p) {
        if(p == 'granted') Notification.permission = p;
      });
      $(this).closest('li').fadeOut();
      return false;
    });
    $ask_for_notifications.find('a.confirm').click(function() {
      $(this).closest('li').fadeOut();
      return false;
    });

    appendToMessages($ask_for_notifications);
  };

  var nickList = function($data) {
    var $nicks = $data.find('[data-nick]');
    var cid = id_as(current_target)[0];
    var extra = [nick];
    var senders = {};

    if($nicks.length) {
      $messages.find('li[data-sender]').each(function(i) {
        senders[$(this).attr('data-sender')] = i;
      });

      $nicks.each(function() {
        var $a = $(this);
        var n = $a.attr('data-nick');
        nicks.add(senders[n] || 1, n);
      });
    }

    if(current_target.indexOf(':23') == -1) {
      extra.unshift(id_as(current_target)[1]);
    }

    $nick_list.find('ul').html(
      $.map(nicks.revrange(0, -1).concat(extra).sortCaseInsensitive(), function(n, i) {
        return '<li><a href="' + $.url_for(cid, n) + '">' + n + '</a></li>';
      }).join('')
    );

    $nick_list.nanoScroller(); // reset scrollbar;
  }

  var receiveMessage = function(e) {
    var $data = $(e.data);
    var cid_target = id_as($data.attr('data-target'));
    var cid_target_selector = targetToSelector($data.attr('data-target'));
    var at_bottom = $win.data('at_bottom');
    var to_current = $('#conversation_' + cid_target_selector).length ? true : false;
    var re;

    $input.removeClass('sending');

    if(typeof cid_target[1] === 'undefined') {
      cid_target[1] = ''; // server messages
    }

    if($data.hasClass('remove-conversation')) {
      reloadConversationList({ goto_current: to_current });
    }
    else if($data.hasClass('add-conversation')) {
      reloadConversationList({ goto_current: true });
    }
    else if(to_current) {
      if($data.hasClass('nicks')) {
        nickList($data);
        return;
      }
      else if($data.hasClass('nick-change')) {
        nicks.rem($data.attr('data-old-nick')).add($data.attr('data-nick'));
        if($data.attr('data-old-nick') == nick) {
          re = new RegExp('\\b' + nick + '\\b', 'i');
          nick = $data.attr('data-nick');
          $input.attr('placeholder', $input.attr('placeholder').replace(re, nick)).attr('title', $input.attr('placeholder'));
        }
      }
      else if($data.hasClass('nick-joined')) {
        nicks.add(0, $data.attr('data-nick'));
        nickList($('<div/>'));
      }
      else if($data.hasClass('nick-parted')) {
        nicks.rem($data.attr('data-nick'));
        nickList($('<div/>'));
      }
      else if($data.attr('data-sender')) {
        nicks.add(new Date().getTime(), $data.attr('data-sender'));
      }

      appendToMessages($data);
    }

    if($data.hasClass('highlight')) {
      var sender = $data.attr('data-sender');
      var what = cid_target[1].indexOf('#') === 0 ? 'mentioned you in ' + cid_target[1] : 'sent you a message';
      $.notify([sender, what].join(' '), $data.find('.content').text(), $data.find('img').attr('src'));
      reloadNotificationList();
    }
    if(at_bottom) {
      $win.scrollTo('bottom');
      $data.find('img').one('load', function() { $win.scrollTo('bottom') });
    }
  };

  var reloadConversationList = function(e) {
    var goto_current = e.goto_current;
    $.get($.url_for('conversations'), function(data) {
      $('ul.conversation-list').replaceWith(data);
      if(goto_current) $('ul.conversation-list').find('.current').click();
      conversation_list = $('ul.conversation-list a').map(function() { return $(this).text() }).get();
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
    $win = $(window);
    if($('section.messages').length === 0) return; // not on chat page
    $('nav a.help').click(function(e) { sendMessage('/help'); $(document).click(); return false; })
    $win.on('scroll', getMessages).on('resize', drawUI);
    $nick_list = $('div.nick-list');
    chat_ws = $.ws($.url_for('socket').replace(/^http/, 'ws'));
    chat_ws.on('message', receiveMessage);
    initInputField();
    initNickList();

    $(document).on('pjax:timeout', function(e) { e.preventDefault(); });
    $(document).pjax('ul.conversation-list a', 'section.messages');
    $(document).pjax('ul.notification-list a', 'section.messages');
    $(document).pjax('div.nick-list a', 'section.messages');
    $('section.messages').on('pjax:end', conversationLoaded);
    $('section.messages').on('pjax:start', function(xhr, options) {
      $('body').loadingIndicator('show');
    });

    $('body').bind('keydown', 'esc', function(e) {
      var $active = $('a[data-toggle]').filter('.active');
      if(!$active.length) return true;
      $active.trigger('deactivate').focus();
      return false;
    });
    $('div.conversation-list, div.notification-list').bind('keydown', 'up', function(e) {
      $(document.activeElement).closest('li').prev().find('a').focus();
      return false;
    });
    $('div.conversation-list, div.notification-list').bind('keydown', 'down', function(e) {
      $(document.activeElement).closest('li').next().find('a').focus();
      return false;
    });

    $('a.notification-list').on('activate', function() {
      var $a = $(this);
      $.post($.url_for('notifications/clear'), function(res) {
        $a.removeClass('alert').children('b').text(0);
      });
      setTimeout(function() { $('div.notification-list a:first').focus(); }, 100);
    });
  });

  $(document).on('completely_ready', function() {
    conversationLoaded();
    initNotifications();
  });

})(jQuery);