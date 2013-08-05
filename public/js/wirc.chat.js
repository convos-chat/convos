;(function($) {
  var $goto_bottom, $input, $win;
  var $ask_for_notifications = $('<li class="notice"><div class="question">Do you want notifications? <a href="#!yes" class="button yes">Yes</a> <a href="#!no" class="button confirm no">No</a></div></li>');
  var $messages = $('<div/>'); // need to be defined
  var nicks = new sortedSet();
  var conversation_list = [];
  var min_width = 700;
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
    this.length++;
    return this;
  };

  $.fn.attachEventsToMessage = function() {
    this.find('h3 a').each(function() {
      this.href = '#' + this.href;
    }).click(function() {
      var n = $(this).text();
      $input.val($input.val() ? $input.val() + ' ' + n + ' ' : n + ': ').focusSoon();
    });

    this.find('.close').click(function() {
      $(this).closest('li').remove();
    });
  };


  $.fn.appendToMessages = function() {
    var $previous = $messages.children('li:last');
    var last_nick = $previous.data('sender') || '';

    this.attachEventsToMessage();

    if(this.hasClass('message') && $previous.hasClass('message')) {
      if(last_nick == this.data('sender')) {
        this.addClass('same-nick').children('h3, .avatar, .timestamp').remove();
      }
    }
    else if(this.hasClass('nick-change')) {
      var re, txt, old = this.find('.old').text(), nick = this.find('.nick').text();
      nicks.add(nicks.score(old), nick).rem(old);
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
      nicks.rem(this.find('.nick').text());
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
    $messages = $('div.messages ul');
    $messages.start_time = parseFloat($messages.data('start-time') || 0);

    $('body').loadingIndicator('hide');
    $('div.nicks.container ul').html('');
    $messages.find('li').attachEventsToMessage();
    nicks.clear();

    if($messages.data('target').indexOf('#') === 0) {
      $input.send('/names', 0).send('/topic', 0);
      $('.without-nick-list').addClass('with-nick-list').removeClass('without-nick-list');
    }
    else {
      $('.with-nick-list').addClass('without-nick-list').removeClass('with-nick-list');
    }

    if(location.href.indexOf('from=') > 0) { // link from notification list
      $messages.end_time = parseFloat($messages.data('end-time') || 0);
      $win.scrollTo(0);
      getMessages();
      reloadNotificationList();
    }
    else {
      $input.focusSoon();
      $win.data('at_bottom', true); // required before drawUI() and scrollTo('bottom')
    }

    if(!Object.equals($input.cidAndTarget(), $messages.cidAndTarget())) {
      reloadConversationList({});
    }

    $input.cidAndTarget($messages); // must be done after Object.equals(...) above
    drawUI();
  };

  var drawConversationMenu = function($message) {
    var $conversations = $('ul.conversations li, div.conversations.container li');
    var $dropdown = $('div.conversations.container ul');
    var $menu = $('nav ul.conversations');
    var available_width = $('nav').width() - $('nav .right').outerWidth() - $('nav a.settings').outerWidth();
    var used_width = 0, unread, $a;

    if($message) {
      $a = $conversations.find('a[href="' + $.url_for($message.data('cid'), $message.data('target')) + '"]');
      unread = parseInt($a.attr('data-unread')) + 1;
      $a.attr('data-unread', unread).attr('title', unread + " unread messages in " + $message.data('target'));
      $a.closest('li').addClass('unread');
    }

    $conversations.each(function() {
      var $li = $(this);
      if(!$li.parent('ul').is('.conversations')) $menu.append($li);
      used_width += $li.find('a').outerWidth();
      if(used_width < available_width) return;
      $dropdown.prepend($li);
    });

    if(used_width >= available_width) {
      $('nav a.conversations.toggler').show();
    }
    else {
      $('nav a.conversations.toggler').trigger('deactivate').hide();
    }
  };

  var drawUI = function() {
    drawConversationMenu();

    $('a[data-toggle]').filter('.active').trigger('activate');

    if($('.without-nick-list').length) {
      $('div.nicks.container').css({ left: '', height: '', display: 'none' });
    }
    else if($win.width() > min_width) {
      $('a.nicks.toggler').trigger('deactivate');
      $('div.nicks.container').css({ left: '', height: '', display: 'block' });
    }
    else if($('a.nicks.toggler').is('.active')) {
      $('div.nicks.container').css({ display: 'block' });
    }
    else {
      $('div.nicks.container').css({ display: 'none' });
    }

    if($win.data('at_bottom')) $win.scrollTo('bottom');
  };

  var getMessages = function() {
    var $height_from = $(document).data('height_from')

    $goto_bottom[$win.scrollTop() + $win.height() < $height_from.height() - 200 ? 'show' : 'hide']();

    if($messages.start_time && $win.scrollTop() == 0) {
      var end_time = $messages.end_time;
      $.get(location.href.replace(/\?.*/, ''), { to: $messages.start_time }, function(data) {
        var $ul = $(data);
        var $li = $ul.children('li:lt(-1)');
        var height_before_prepend = $height_from.height();
        $messages.end_time = end_time;
        if(!$li.length) return;
        $messages.start_time = parseFloat($ul.data('start-time'));
        $messages.prepend($li);
        $win.scrollTop($height_from.height() - height_before_prepend);
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

    var autocomplete = function(e) {
      var val = $input.val();
      var offset = val.lastIndexOf(' ') + 1;
      var re = new RegExp('^' + RegExp.escape(val.substr(offset)), 'i');
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
    };

    $.get($.url_for(['command-history']), function(data) {
      $input.history = data;
      $input.history_i = $input.history.length;
    });

    $input.doubletap(autocomplete);
    $input.bind('keydown', function(e) { if(e.keyCode !== 9) complete = false; }); // not tab
    $input.bind('keydown', 'tab', autocomplete);
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
    });
    $ask_for_notifications.find('a.no').click(function() {
      $(this).closest('li').fadeOut();
    });
  };

  var initPjax = function() {
    $(document).on('pjax:timeout', function(e) { e.preventDefault(); });
    $(document).pjax('nav a.conversation', 'div.messages');
    $(document).pjax('div.container a', 'div.messages');
    $('div.messages').on('pjax:end', conversationLoaded);
    $('div.messages').on('pjax:start', function(xhr, options) { $('body').loadingIndicator('show'); });
  }

  var initSocket = function() {
    $input.history = [];
    $input.history_i = 0;
    $input.socket = window.ws($input.closest('form').data('socket-url'));
    $input.socket.onmessage = receiveMessage;
    $input.socket.onopen = function() { $input.removeClass('disabled'); };
    $input.socket.onclose = function() { $input.addClass('disabled'); };
    $input.send = function(message, history) {
      if(message.length == 0) return $input;
      $input.socket.send($('<div/>').cidAndTarget($messages).attr('data-history', history).text(message).prop('outerHTML'));
      $input.addClass('sending').siblings('.menu').hide();
      if(history) $input.history.push(message);
      $input.history_i = $input.history.length;
      return $input;
    };
  }

  var initShortcuts = function() {
    $('body').bind('keydown', 'esc', function(e) {
      e.preventDefault();
      var $active = $('a[data-toggle]').filter('.active');
      if(!$active.length) return true;
      $active.trigger('deactivate').focus();
    });

    $('body, input').bind('keydown', 'shift+return', function(e) {
      e.preventDefault();
      $('a[data-toggle]').not($win.width() < min_width ? 'whatever' : '.nicks.toggler').trigger('deactivate');
      if(document.activeElement == $input.get(0)) {
        $('nav ul.conversations a').slice(0, 2).eq(-1).focus();
      }
      else {
        $input.focus();
      }
    });

    var upDown = function(method, page) {
      var $e, i;
      return function(e) {
        $e = $(document.activeElement).closest('li');
        if($e.length === 0) return true;
        i = page ? parseInt($e.closest('div.container').height() / $e.height()) + 1 : 0;
        $e = $e[method]();
        if($e.length <= i) i = $e.length - 1;
        $e.eq(i).find('a').focus();
        return false;
      };
    };

    $('body').bind('keydown', 'up', upDown('prevAll', 0));
    $('body').bind('keydown', 'pageup', upDown('prevAll', 1));
    $('body').bind('keydown', 'down', upDown('nextAll', 0));
    $('body').bind('keydown', 'pagedown', upDown('nextAll', 1));
  };

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

    if(nicks.length) {
      $('div.nicks.container ul').html(
        $.map(nicks.revrange(0, -1).sortCaseInsensitive(), function(n, i) {
          return '<li><a href="' + $.url_for(cid, n) + '">' + n + '</a></li>';
        }).join('')
      );
      $('div.nicks.container').nanoScroller(); // reset scrollbar;
    }
  }

  var receiveMessage = function(e) {
    var $message = $(e.data);
    var at_bottom = $win.data('at_bottom');
    var to_current;

    $input.removeClass('sending').siblings('.menu').show();

    if($message.data('target') === 'any') {
      $message.data('target', $messages.data('target')).data('cid', $messages.data('cid'));
    }

    to_current = Object.equals($message.cidAndTarget(), $messages.cidAndTarget());

    if($message.hasClass('highlight')) {
      var sender = $message.data('sender');
      var what = $message.data('target').indexOf('#') === 0 ? 'mentioned you in ' + $message.data('target') : 'sent you a message';
      $.notify([sender, what].join(' '), $message.find('.content').text(), $message.find('img').attr('src'));
      if(!to_current) reloadNotificationList();
    }

    if($message.hasClass('remove-conversation')) {
      reloadConversationList({ goto_current: to_current });
    }
    else if($message.hasClass('add-conversation')) {
      reloadConversationList({ goto_current: true });
    }
    else if(to_current) {
      $message.appendToMessages();
    }
    else if($message.hasClass('message')) {
      drawConversationMenu($message);
    }

    if(at_bottom) {
      $win.scrollTo('bottom');
      $message.find('img').one('load', function() { $win.scrollTo('bottom') });
    }
  };

  var reloadConversationList = function(e) {
    var goto_current = e.goto_current;
    $.get($.url_for('conversations'), function(data) {
      $('ul.conversations').replaceWith(data);
      $('div.conversations.container ul').html('');
      if(goto_current) $('ul.conversations li:first a').click();
      conversation_list = $('ul.conversations a').map(function() { return $(this).text(); }).get();
      drawConversationMenu();
    });
  };

  var reloadNotificationList = function(e) {
    var $notification_list = $('div.notifications.container');
    var $n_notifications = $('a.notifications.toggler');
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
    if($('div.messages').length === 0) return; // not on chat page
    $goto_bottom = $('div.goto-bottom a');
    $input = $('footer form input[name="message"]');
    $win = $(window);
    conversation_list = $('ul.conversations a').map(function() { return $(this).text(); }).get();

    initShortcuts();
    initSocket();
    initPjax();
    initInputField();

    $('nav a.notifications.toggler').on('activate', function() {
      $.post($.url_for('notifications/clear'));
      $(this).removeClass('alert').children('b').text(0);
    });

    $('nav a.toggler').initDropDown();
    $('nav, div.container, div.goto-bottom').fastButton();
    $('nav a.settings').click(function(e) { location.href = this.href; });
    $('footer a.help').click(function(e) { $input.send('/help', 0); return false; })
    $goto_bottom.click(function(e) { e.preventDefault(); $win.scrollTo('bottom'); });
    $win.on('scroll', getMessages).on('resize', drawUI);
  });

  $(window).load(function() {
    if($('div.messages').length === 0) return; // not on chat page
    initNotifications();
    conversationLoaded();
  });

})(jQuery);
