;(function($) {
  var $goto_bottom, $input, $win;
  var $messages = $('<div/>'); // need to be defined
  var reconnectHandler;
  var nicks = new sortedSet();
  var running_on_ios = /(iPad|iPhone|iPod)/g.test(navigator.userAgent);
  var conversation_list = [];
  var min_width = 700;
  var commands = [
    '/help',
    '/join #',
    '/query ',
    '/msg ',
    '/me ',
    '/say ',
    '/nick ',
    '/close',
    '/part ',
    '/names ',
    '/mode ',
    '/topic ',
    '/reconnect',
    '/whois ',
    '/list'
  ];

  window.convos = {
    conversation_list: conversation_list,
    messages: $messages,
    nicks: nicks
  };

  $.fn.attachEventsToMessage = function() {
    return this.each(function() {
      var $message = $(this);
      $message.find('h3 a').click(function(e) {
        e.preventDefault();
        if($(this).hasClass('goto-network')) {
          $.pjax.click(e, { container: $('div.messages') });
        }
        else {
          var n = $(this).text();
          $input.val($input.val() ? $input.val() + ' ' + n + ' ' : n + ': ').focusSoon();
        }
      });

      // embed media
      $message.find('a.embed').each(function() {
        var $a = $(this);
        $.get($.url_for('/oembed'), { url: this.href }, function(embed_code) {
          var at_bottom = $win.data('at_bottom');
          var $embed_code = $(embed_code);
          $a.closest('div').after($embed_code);
          if(at_bottom) {
            $win.scrollTo('bottom');
            $embed_code.find('img').one('load', function() { $win.scrollTo('bottom') });
          }
        });
      });

      $message.find('.close').click(function() { $(this).closest('li').remove(); });
      $message.filter('.historic-message').find('a.button.newer').click(getNewMessages);
      $message.filter('.historic-message').find('a.button.current').click(function(e) {
        return $.pjax.click(e, { container: 'div.messages' });
      });
    });
  };

  $.fn.appendToMessages = function() {
    var $previous = $messages.children('li').not('.message-pending').eq(-1);
    var last_nick = $previous.data('sender') || '';

    this.attachEventsToMessage();

    if(this.hasClass('message') && $previous.hasClass('message')) {
      if(last_nick == this.data('sender')) {
        this.addClass('same-nick').children('h3, .avatar, .timestamp').remove();
      }
    }
    else if(this.hasClass('nick-change')) {
      var new_nick = this.find('.nick').text();
      var old_nick = this.find('.old').text();
      var old_score = nicks.score(old_nick);
      var re, txt;

      console.log('new_nick=' + new_nick + ', old_nick=' + old_nick + ', old_score=' + old_score);

      if(old_nick == $messages.data('nick')) {
        re = new RegExp('\\b' + old_nick + '\\b', 'i');
        txt = $input.attr('placeholder').replace(re, new_nick);
        $input.attr('placeholder', txt).attr('title', txt);
        $messages.data('nick', new_nick);
      }
      if(typeof old_score == 'undefined') {
        return; // do not want to show joined when in other channel
      }
      else {
        nicks.add(old_score, new_nick).rem(old_nick);
        nickList($('<div/>'));
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
    else if(this.hasClass('nick-quit')) {
      var nick = this.find('.nick').text();
      if(nicks.score(nick)) {
        nicks.rem(nick);
        nickList($('<div/>'));
      }
      else {
        return;
      }
    }
    else if(this.hasClass('nicks')) {
      nickList(this);
      return;
    }
    else if(this.data('sender') && this.data('sender') != $messages.data('nick')) {
      nicks.add(new Date().getTime(), this.data('sender'));
    }

    $messages.append(this.fadeIn('fast'));
  };

  $.fn.hostAndTarget = function($from) {
    if($from) {
      return this
        .attr('data-network', $from.data('network')).attr('data-target', $from.data('target'))
        .data('network', $from.data('network')).data('target', $from.data('target'))
    }
    else {
      return { network: this.data('network'), target: this.data('target') };
    }
  };

  var conversationLoaded = function(e, data, status_text, xhr, options) {
    var $doc = $(data || '<div></div>');

    $messages = $('div.messages ul');
    $messages.start_time = parseFloat($messages.data('start-time') || 0);

    $('body').attr('class', $messages.attr('class')).loadingIndicator('hide');
    $messages.find('li').attachEventsToMessage();
    nicks.clear();

    $doc.filter('form.connection-control').each(function() {
      $('form.connection-control').attr('action', this.action);
    });
    $doc.find('div.sidebar.container').each(function() {
      $('div.sidebar.container ul').html($(this).find('ul:first').children());
    });

    if($messages.attr('data-target') && $messages.hasClass('with-sidebar')) {
      $input.send('/names', 0).send('/topic', { 'data-history': 0 });
    }

    if(location.href.indexOf('from=') > 0) { // link from notification list
      $messages.end_time = parseFloat($messages.data('end-time') || 0);
      $win.scrollTo(0);
      getHistoricMessages();
    }
    else if($messages.length ) {
      if(!$.supportsTouch) $input.focusSoon();
      $win.data('at_bottom', true); // required before drawUI() and scrollTo('bottom')
    }

    if(!Object.equals($input.hostAndTarget(), $messages.hostAndTarget())) {
      reloadConversationList({});
    }

    if(initNotifications.asked == 'undefined') {
      initNotifications();
    }

    $input.hostAndTarget($messages); // must be done after Object.equals(...) above
    drawSettings();
    drawUI();
  };

  var drawConversationMenu = function($message) {
    var $conversations = $('ul.conversations li, div.conversations.container li');
    var $dropdown = $('div.conversations.container ul');
    var $menu = $('nav ul.conversations');
    var available_width = $('nav').width() - $('nav .right').outerWidth();
    var used_width = 0, unread, $a;

    if($message) {
      $a = $conversations.find('a[href="' + $.url_for($message.data('network'), $message.data('target')) + '"]');
      unread = parseInt($a.attr('data-unread')) + 1;
      $a.attr('data-unread', unread).attr('title', unread + " unread messages in " + $message.data('target'));
      $a.closest('li').addClass('unread');
    }

    $conversations.each(function() {
      var $li = $(this);
      if(!$li.parent('ul').is('.conversations')) $menu.append($li);
      used_width += $li.find('a').outerWidth();
      if(used_width < available_width) return;
      $dropdown.append($li);
    });

    if(used_width >= available_width) {
      $('nav a.conversations.toggler').show();
    }
    else {
      $('nav a.conversations.toggler').trigger('deactivate').hide();
    }
  };

  var drawSettings = function() {
    var channels = {};
    var networkChange;

    $('select#name option').each(function() {
      channels[this.value] = ($(this).attr('data-channels') || '').split(' ');
    });

    networkChange = function(val) {
      var s = $('select#channels')[0].selectize
      s.clearOptions();
      s.addOption($.map(channels[val], function(i) { return { value: i, text: i,  }; }));
      s.refreshOptions(false);
      s.setValue(channels[val].join(' '));
    };

    $('select#name').selectize({
      create: false,
      openOnFocus: true,
      onChange: networkChange
    }).trigger('change');

    $('input#channels').selectize({
      delimiter: ' ',
      persist: false,
      openOnFocus: true,
      create: function(value) {
        if(!/^[#&]/.test(value)) value = '#' + value;
        return { value: value, text: value };
      }
    });
  };

  var drawUI = function() {
    drawConversationMenu();

    $('a[data-toggle]').filter('.active').trigger('activate');

    if($('body').is('.without-sidebar, .historic')) {
      $('div.sidebar.container').css({ left: '', height: '', display: 'none' });
    }
    else if($win.width() > min_width) {
      $('a.sidebar.toggler').trigger('deactivate');
      $('div.sidebar.container').css({ left: '', height: '', display: 'block' });
    }
    else if($('a.sidebar.toggler').is('.active')) {
      $('div.sidebar.container').css({ display: 'block' });
    }
    else {
      $('div.sidebar.container').css({ display: 'none' });
    }

    if($win.data('at_bottom')) $win.scrollTo('bottom');
  };

  var getHistoricMessages = function() {
    var $height_from = $(document).data('height_from')

    $goto_bottom[$win.scrollTop() + $win.height() < $height_from.height() - 200 ? 'show' : 'hide']();

    if($messages.start_time && $win.scrollTop() == 0) {
      var end_time = $messages.end_time;
      $.get(location.href.replace(/\?.*/, ''), { to: $messages.start_time }, function(data) {
        var $ul = $(data).find('ul[data-network]');
        var $li = $ul.children('li:lt(-1)');
        var height_before_prepend = $height_from.height();
        $messages.end_time = end_time;
        if(!$li.length) return;
        $messages.start_time = parseFloat($ul.data('start-time'));
        $messages.prepend($li.attachEventsToMessage());
        $win.scrollTop($height_from.height() - height_before_prepend);
      });
      $messages.start_time = $messages.end_time = 0;
    }

    return false;
  };

  var getNewMessages = function(e) {
    var $btn = $(this);
    var start_time = $messages.start_time;
    if(!e.silent) {
      $('body').loadingIndicator('show');
    }
    if($messages.end_time) {
      $.get(location.href.replace(/\?.*/, ''), { from: $messages.end_time }, function(data) {
        var $ul = $(data);
        var $li = $ul.children('li:gt(0)');
        if(!e.silent) $('body').loadingIndicator('hide');
        $btn.closest('li').remove();
        $messages.start_time = start_time;
        if(!$li.length) return;
        $messages.end_time = parseFloat($ul.data('end-time'));
        $li.each(function() { $(this).appendToMessages(); });
        if(!$li.filter('.historic-message').length) {
          $('body').attr('class', /^[#&]/.test($messages.hostAndTarget().target) ? 'with-sidebar' : 'without-sidebar');
          if(!e.goto_bottom) $win.data('at_bottom', false); // prevent scroll to bottom
          drawUI();
        }
      });
    }
    $messages.start_time = $messages.end_time = 0;
    return false;
  };

  var initAddConversation = function() {
    $('.add-conversation form').submit(function(e) {
      var $form = $(this);
      var network = $form.find('select[name="name"]').val();
      var channel = $form.find('input[name="channel"]').val().replace(/^\s*#/, '');

      e.preventDefault();
      $input.send('/join #' + channel, { 'data-network': network });
      $input.focus();
      $('a[data-toggle]').filter('.active').trigger('deactivate');
    });
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

    $.get($.url_for('/chat/command-history'), noCache({}), function(data) {
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
      $input.send($input.val(), { 'data-history': 1 }).val('');
    });
  };

  var initNotifications = function() {
    if(Notification.permission === 'granted') return;
    if(Notification.permission === 'unsupported') return;
    if(Notification.permission === 'denied') return;

    var $ask_for_notifications = $('div.notification.question');
    initNotifications.asked = true;
    $ask_for_notifications.find('a.yes').off('click').click(function() {
      Notification.requestPermission(function() {});
      $ask_for_notifications.hide();
      return false;
    });
    $ask_for_notifications.find('a.no').off('click').click(function() {
      $ask_for_notifications.fadeOut('fast');
      return false;
    });
    $ask_for_notifications.show();
  };

  var initPjax = function() {
    $(document).on('pjax:timeout', function(e) { e.preventDefault(); });
    $(document).pjax('nav a.conversation', 'div.messages', { fragment: 'div.messages' });
    $(document).pjax('nav a.convos', 'div.messages', { fragment: 'div.messages' });
    $(document).pjax('div.container a', 'div.messages', { fragment: 'div.messages' });

    $('div.messages').on('pjax:beforeSend', function(xhr, options) { return !$(this).hasClass('no-pjax'); });
    $('div.messages').on('pjax:start', function(xhr, options) { $('body').loadingIndicator('show'); });
    $('div.messages').on('pjax:success', conversationLoaded);
  }

  var initSocket = function() {
    var url = $input.closest('form').data('socket-url');
    if(!url) return;
    $input.history = [];
    $input.history_i = 0;
    $input.socket = new ReconnectingWebSocket(url);
    $input.socket.opened = 0;
    $input.socket.onmessage = receiveMessage;
    $input.socket.debug = location.href.indexOf('#debug') > 0 ? true : false;
    $input.socket.onopen = function() {
      $input.removeClass('disabled');
      $input.socket.reconnectInterval = 500;
      if($input.socket.opened++) getNewMessages({ goto_bottom: true, silent: true });
    };
    $input.socket.onerror = function(e) {
      if($input.socket.reconnectInterval < 5e3) $input.socket.reconnectInterval += 500;
    };
    $input.socket.onclose = function() {
      $input.addClass('disabled');
    };
    reconnectHandler= window.setTimeout(function() { $input.socket.refresh()},60000);
    $input.send = function(message, attr) {
      if(message.length == 0) return $input;
      var uuid = window.guid();
      attr = attr || {};
      if(!message.match('^\/')) {
        var $pendingMessage = $('<li class="message-pending"><div class="content"></div></li>').attr('id', uuid).hostAndTarget($messages);
        $pendingMessage.find('.content').text(message);
        setTimeout(function() { messageFailed($pendingMessage); }, 10000);
        $pendingMessage.appendToMessages();
        $win.scrollTo('bottom');
      }
      $input.socket.send($('<div/>').hostAndTarget($messages).attr('id', uuid).attr(attr).text(message).prop('outerHTML'));
      $input.addClass('sending').siblings('.menu').hide();
      if(attr['data-history']) $input.history.push(message);
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
      $('a[data-toggle]').not($win.width() < min_width ? 'whatever' : '.sidebar.toggler').trigger('deactivate');
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
    var network = $messages.data('network');
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
      $('div.sidebar.container ul').html(
        $.map(nicks.revrange(0, -1).sortCaseInsensitive(), function(n, i) {
          return '<li><a href="' + $.url_for(network, n) + '">' + n + '</a></li>';
        }).join('')
      );
      $('div.sidebar.container').nanoScroller(); // reset scrollbar;
    }
  }

  var messageFailed = function($message) {
    var uuid = $message.attr('id');
    $messages.find('#' + uuid)
      .filter('.message-pending')
      .addClass('message-error')
      .removeClass('message-pending')
      .prepend('<h3>Could not send message</h3>')
      .prepend('<span class="actions"><button class="resend-message">Resend</button> <button class="remove-message">&times;</button></span>')
      ;
  }

  var noCache = function(args) {
    args._ts = new Date().getTime();
    return args;
  };

  var receiveMessage = function(e) {
    var $message = $(e.data);

    window.clearTimeout(reconnectHandler);
    reconnectHandler= window.setTimeout(function() { $input.socket.refresh() },60000);

    if($message.hasClass('ping')) {
      return $input.socket.send('<div class="pong"/>')
    }

    var at_bottom = $win.data('at_bottom');
    var to_current = false;
    var uuid = $message.attr('id');

    if($messages.find('#' + uuid).length) {
      if($message.hasClass('error')) {
        messageFailed($message);
      }
      else {
        $messages.find('#' + uuid).remove();
      }
    }

    $input.removeClass('sending').siblings('.menu').show();

    if($message.data('target') === 'any') {
      $message.data('target', $messages.data('target'));
      if(!$message.data('network')) $message.data('network', $messages.data('network'));
    }
    if($('body').attr('class').indexOf('-sidebar') > 0) {
      to_current = Object.equals($message.hostAndTarget(), $messages.hostAndTarget());
    }
    if($message.hasClass('highlight')) {
      var sender = $message.data('sender');
      var what = /^[#&]/.test($message.data('target')) ? 'mentioned you in ' + $message.data('target') : 'sent you a message';
      var reload_notification_list_args = {};
      $.notify([sender, what].join(' '), $message.find('.content').text(), $message.find('img').attr('src'));
      if($win.data('has_focus') && to_current) reload_notification_list_args.clear_notification = 0;
      reloadNotificationList(reload_notification_list_args);
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

    if($win.data('at_bottom')) $win.scrollTo('bottom');
  };

  var reloadConversationList = function(e) {
    var goto_current = e.goto_current;
    $.get($.url_for('/chat/conversations'), noCache({}), function(data) {
      $('ul.conversations').replaceWith(data);
      $('div.conversations.container ul').html('');
      if(goto_current) $('ul.conversations li.first a').click();
      conversation_list = $('ul.conversations a').map(function() { return $(this).text(); }).get();
      drawConversationMenu();
    });
  };

  var reloadNotificationList = function(e) {
    var $notification_list = $('div.notifications.container ul').parent();
    var $n_notifications = $('a.notifications.toggler');
    var reload_notification_list_args = {};
    var n;

    if(typeof e.clear_notification != 'undefined') {
      reload_notification_list_args.notification = e.clear_notification;
    }

    $.get($.url_for('/chat/notifications'), noCache(reload_notification_list_args), function(data) {
      $notification_list.html(data);
      n = parseInt($notification_list.children('ul').data('notifications'), 10);
      if(n==0) { n='' }
      $n_notifications.children('b').text(n);
      $n_notifications[n ? 'addClass' : 'removeClass']('alert');
    });
  };

  $(document).ready(function() {
    $goto_bottom = $('div.goto-bottom a');
    $input = $('footer form input[name="message"]');
    $win = $(window);
    conversation_list = $('ul.conversations a').map(function() { return $(this).text(); }).get();

    if($input.length == 0) {
      return;
    }

    $input.focus();

    $.ajaxSetup({
      error: function(jqXHR, exception) {
        console.log('ajax: ' + this.url + ' failed: ' + exception);
      }
    });

    if(running_on_ios) {
      $('input, textarea').on('click', function() {
        $('nav.bar').hide();
      }).on('focusout', function() {
        $('nav.bar').show();
      });
    }

    initShortcuts();
    initSocket();
    initPjax();
    initInputField();
    initAddConversation();

    $('nav a.notifications.toggler').on('activate', function() {
      $.post($.url_for('/chat/notifications/clear'));
      $(this).removeClass('alert').children('b').text('');
    });

    $('nav a.toggler').initDropDown();
    $('nav, div.container, div.goto-bottom').fastButton();
    $('footer a.help').click(function(e) { $input.send('/help', { 'data-history': 0 }); return false; })
    $goto_bottom.click(function(e) { e.preventDefault(); $win.scrollTo('bottom'); });
    $win.on('scroll', getHistoricMessages).on('resize', drawUI);
    $('.messages').on('click', '.resend-message', function() {
      $input.socket.buffer = []; // need to clear buffer when resending messages
      $input.send($(this).parents('li').find('.content').text());
      $(this).parents('li').remove();
    });
    $('.messages').on('click','.remove-message', function() {
      $(this).parents('li').remove();
    });
  });

  $(document).ready(function() {
    $('.login, .register').find('form input[type="text"]:first').focus();
    if(!$input.length) drawSettings();
  });

  $(window).load(function() {
    if($input.length) conversationLoaded();
  });

})(jQuery);
