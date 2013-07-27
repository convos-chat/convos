;(function($) {
  var $input, $messages, $nick_list, $win;
  var $ask_for_notifications = $('<li class="notice"><div class="question">Do you want notifications? <a href="//yes" class="button yes">Yes</a> <a href="//no" class="button confirm no">No</a></div></li>');
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
    if(member !== $messages.data('nick')) this.set[member] = score;
    return this;
  };

  $.fn.appendToMessages = function() {
    var $previous = $messages.children('li:last');
    var last_nick = $previous.data('sender') || '';

    if(this.hasClass('message') && $previous.hasClass('message')) {
      if(last_nick == this.data('sender')) {
        this.addClass('same-nick').children('h3, .avatar, .timestamp').remove();
      }
    }
    else if(this.hasClass('nick-change')) {
      var re, txt, old = this.find('.old').text(), nick = this.find('.nick').text();
      nicks.rem(old).add(nick);
      if(old == $messages.data('nick')) {
        re = new RegExp('\\b' + old + '\\b', 'i');
        txt = $input.attr('placeholder').replace(re, nick);
        $input.attr('placeholder', txt).attr('title', txt);
        $messages.data('nick', nick);
      }
    }
    else if(this.hasClass('nick-joined')) {
      nicks.add(0, this.find('.nick').text());
      nickList($('<div/>'));
    }
    else if(this.hasClass('nick-parted')) {
      nicks.rem(0, this.find('.nick').text());
      nickList($('<div/>'));
    }
    else if(this.hasClass('nicks')) {
      nickList(this);
      return;
    }
    else if(this.data('sender')) {
      nicks.add(new Date().getTime(), this.data('sender'));
    }

    $messages.append(this.fadeIn('fast'));
  };

  $.fn.cidAndTarget = function($from) {
    if($from) {
      return this
        .attr('data-cid', $from.data('cid')).attr('data-target', $from.data('target'))
        .data('cid', $from.data('cid')).data('target', $from.data('target'))
    }
    else {
      return { cid: this.data('cid'), cid: this.data('target') };
    }
  };

  var conversationLoaded = function() {
    $messages = $('section.messages ul');
    $messages.start_time = parseFloat($messages.data('start-time') || 0);
    $('a.conversation-list').trigger('deactivate');
    $('a.notification-list').trigger('deactivate');
    if($win.smallScreen()) $('div.nick-list').animate({ right: '-180px' });

    if($messages.data('target').indexOf('#') === 0) {
      $input.send('/names', 0).send('/topic', 0);
    }
    if(!Object.equals($input.cidAndTarget(), $messages.cidAndTarget())) {
      reloadConversationList({});
    }

    if(location.href.indexOf('from=') > 0) { // link from notification list
      $messages.end_time = parseFloat($messages.data('end-time') || 0);
      $win.scrollTo(0);
      getMessages();
      reloadNotificationList();
    }
    else {
      $input.focus();
      $win.data('at_bottom', true); // required before drawUI() and scrollTo('bottom')
    }

    $('body').loadingIndicator('hide');
    $input.cidAndTarget($messages);
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

    $nick_list.css({ right: $win.smallScreen() ? '-180px' : '0' });

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
        var $ul = $(data);
        var $li = $ul.children('li:lt(-1)');
        var height_before_prepend = $(document).data('heigth_from').height();
        $messages.end_time = end_time;
        if(!$li.length) return;
        $messages.start_time = parseFloat($ul.data('start-time'));
        $messages.prepend($li);
        $win.scrollTop($(document).data('heigth_from').height() - height_before_prepend);
      });
      $messages.start_time = $messages.end_time = 0;
    }
    else if($messages.end_time && $win.data('at_bottom')) {
      var start_time = $messages.start_time;
      $.get(location.href.replace(/\?.*/, ''), { from: $messages.end_time }, function(data) {
        var $ul = $(data);
        var $li = $ul.children('li:gt(0)');
        $messages.start_time = start_time;
        if(!$li.length) return;
        $messages.end_time = parseFloat($ul.data('end-time'));
        $li.each(function() { $(this).appendToMessages(); });
      });
      $messages.start_time = $messages.end_time = 0;
    }
  };

  var initInputField = function() {
    var current = '';
    var complete, val, offset, re;

    $.get($.url_for(['command-history']), function(data) {
      $input.history = data;
      $input.history_i = $input.history.length;
    });

    $('body, input').bind('keydown', 'shift+return', function(e) {
      e.preventDefault();
      $('a[data-toggle]').trigger('deactivate');
      if(document.activeElement == $input.get(0)) {
        $('nav .conversation-list a').slice(0, 2).eq(-1).focus();
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
      complete = complete || {
        i: 0,
        prefix: val.substr(0, offset),
        list: $.map(
          $.grep(
            nicks.revrange(0, -1).concat(conversation_list).concat(commands).unique(),
            function(v, i) {
              re = re || new RegExp('^' + RegExp.escape(val.substr(offset)), 'i');
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
      if($input.history_i == 0) return;
      if($input.history_i == $input.history.length) current = $input.val();
      $input.val($input.history[--$input.history_i]);
    });
    $input.bind('keydown', 'down', function(e) {
      e.preventDefault();
      if(++$input.history_i == $input.history.length) return $input.val(current);
      if($input.history_i > $input.history.length) return $input.history_i = $input.history.length;
      $input.val($input.history[$input.history_i]);
    });
    $input.closest('form').submit(function(e) {
      e.preventDefault();
      $input.send($input.val(), 1).val('');
    });
  };

  var initNotifications = function() {
    if(Notification.permission === 'granted') return;
    if(Notification.permission === 'unsupported') return;
    if(Notification.permission === 'denied') return;

    $ask_for_notifications.appendToMessages();
    $ask_for_notifications.find('a.yes').click(function() {
      Notification.requestPermission();
      $(this).closest('li').fadeOut();
      return false;
    });
    $ask_for_notifications.find('a.no').click(function() {
      $(this).closest('li').fadeOut();
      return false;
    });
  };

  var initPjax = function() {
    $(document).on('pjax:timeout', function(e) { e.preventDefault(); });
    $(document).pjax('ul.conversation-list a', 'section.messages');
    $(document).pjax('ul.notification-list a', 'section.messages');
    $(document).pjax('div.nick-list a', 'section.messages');
    $('section.messages').on('pjax:end', conversationLoaded);
    $('section.messages').on('pjax:start', function(xhr, options) {
      $('body').loadingIndicator('show');
    });
  }

  var initSocket = function() {
    $input.history = [];
    $input.history_i = 0;
    $input.socket = $.ws($input.closest('form').data('socket-url'));
    $input.socket.on('message', receiveMessage);
    $input.send = function(message, history) {
      if(message.length == 0) return $input;
      $input.socket.send($('<div/>').cidAndTarget($messages).attr('data-history', history).text(message).prop('outerHTML'));
      $input.addClass('sending');
      if(history) $input.history.push(message);
      $input.history_i = $input.history.length;
      return $input;
    };
  }

  var nickList = function($data) {
    var $nicks = $data.find('[data-nick]');
    var cid = $messages.data('cid');
    var senders = {};

    if($nicks.length) {
      $messages.find('li[data-sender]').each(function(i) {
        senders[$(this).data('sender')] = i;
      });

      $nicks.each(function() {
        var $a = $(this);
        var n = $a.data('nick');
        nicks.add(senders[n] || 1, n);
      });
    }

    $nick_list.find('ul').html(
      $.map(nicks.revrange(0, -1).sortCaseInsensitive(), function(n, i) {
        return '<li><a href="' + $.url_for(cid, n) + '">' + n + '</a></li>';
      }).join('')
    );

    $nick_list.nanoScroller(); // reset scrollbar;
  }

  var receiveMessage = function(e) {
    var $message = $(e.data);
    var at_bottom = $win.data('at_bottom');
    var to_current = Object.equals($message.cidAndTarget(), $messages.cidAndTarget());

    $input.removeClass('sending');

    if($message.hasClass('remove-conversation')) {
      reloadConversationList({ goto_current: to_current });
    }
    else if($message.hasClass('add-conversation')) {
      reloadConversationList({ goto_current: true });
    }
    else if(to_current) {
      $message.appendToMessages();
    }

    if($message.hasClass('highlight')) {
      var sender = $message.data('sender');
      var what = $message.data('target').indexOf('#') === 0 ? 'mentioned you in ' + $message.data('target') : 'sent you a message';
      $.notify([sender, what].join(' '), $message.find('.content').text(), $message.find('img').attr('src'));
      reloadNotificationList();
    }
    if(at_bottom) {
      $win.scrollTo('bottom');
      $message.find('img').one('load', function() { $win.scrollTo('bottom') });
    }
  };

  var reloadConversationList = function(e) {
    var goto_current = e.goto_current;
    $.get($.url_for('conversations'), function(data) {
      $('ul.conversation-list').replaceWith(data);
      if(goto_current) $('ul.conversation-list').find('.current').click();
      conversation_list = $('ul.conversation-list a').map(function() { return $(this).text(); }).get();
      drawUI();
    });
  };

  var reloadNotificationList = function(e) {
    var $notification_list = $('div.notification-list');
    var $n_notifications = $('a.notification-list');
    var n;

    $.get($.url_for('notifications'), function(data) {
      $notification_list.html(data);
      n = parseInt($notification_list.children('ul').data('notifications'), 10);
      $n_notifications.children('b').text(n);
      if($notification_list.find('li').length) $n_notifications.removeClass('hidden');
      $n_notifications[n ? 'addClass' : 'removeClass']('alert');
    });
  };

  $(document).ready(function() {
    if($('section.messages').length === 0) return; // not on chat page
    $input = $('footer form input[name="message"]');
    $nick_list = $('div.nick-list');
    $win = $(window);
    conversation_list = $('ul.conversation-list a').map(function() { return $(this).text(); }).get();

    initSocket();
    initInputField();
    initPjax();

    $win.on('scroll', getMessages).on('resize', drawUI);
    $('nav a.help').click(function(e) {
      $input.send('/help', 0);
      return false;
    })
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
      $('div.notification-list a:first').focusSoon();
    });
    $nick_list.addClass('nanoscroller').wrapInner('<div class="content"/>').nanoScroller({
      preventPageScrolling: true
    });

    conversationLoaded();
  });

  $(document).on('load', function() {
    initNotifications();
    drawUI();
  });

})(jQuery);
