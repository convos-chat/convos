;(function($) {
  window.convos = window.convos || {};
  window.link_embedder_text_gist_github_styled = 1; // custom gist styling

  convos.responsiveWidth = 700; // see _variables.scss
  convos.at_bottom = true; // start ui scrolled to bottom
  convos.at_bottom_threshold = !!('ontouchstart' in window) ? 110 : 40;
  convos.current = {};
  convos.isChannel = function(str) { return str.match(/^[#&]/); };

  twttr.events.bind('rendered', function(e) {
    var $p = $(e.target).closest('li');
    if ($p.data('at_bottom')) $(window).scrollTo('bottom');
  });

  convos.on('channel-info', function(network, name, info) {
    if (network != convos.current.network) return;
    convos.current.channels = convos.current.channels || {};
    convos.current.channels[name] = info;
    if (convos.current.channels._timer) clearTimeout(convos.current.channels._timer);
    convos.current.channels._timer = setTimeout(function() { $('div.messages ul .channel-list input').keyup(); }, 500);
  });

  convos.on('channel-list', function($message) {
    var $dl = $message.find('dl');

    // remove existing
    $('div.messages ul .channel-list').each(function() { if ($message[0] != this) $(this).remove(); });

    $message.contents().each(function() {
      if (this.nodeType == 8) convos.current.channels = jQuery.parseJSON(this.nodeValue);
    });

    $message.find('input').on('keyup', function(e) { // filter channel list
      var re = new RegExp(this.value, 'i');
      var names = [];
      var i = 0;

      for (name in convos.current.channels) {
        if (name.match(re)) names.push(name);
      }

      $dl.html('');
      $.each(names.sort(function(a, b) { return a.length - b.length; }), function() {
        if (i++ > 10) return false;
        var data = convos.current.channels[this];
        $dl.append('<dt><a href="cmd:///join ' + this + '">' + data.name + '</a> (' + data.visible +')</dt><dd title="' + data.title + '">' + (data.title || 'No topic') + '</dd>');
      });

      if (!$dl.children().length) $dl.append('<dt>No matching channel names.</dt>');
    }).keyup().focus();

    $message.find('form').on('submit', function(e) {
      e.preventDefault();
      var a = $dl.find('a')[0];
      if (a) a.click();
    });

    // prevent jumping when filtering
    $message.on('addedToMessages', function() { $(this).height($(this).height() < 140 ? $(this).height() * 5 : $(this).height()); });
    $(window).scrollTo('bottom');
  });

  convos.on('help', function($message) {
    $('div.messages ul .help').each(function() { if ($message[0] != this) $(this).remove(); });
  });

  convos.goForwardInHistory = function(e) {
    $(this).closest('li').remove();
    if (e) e.preventDefault();
    if (!convos.current.end_time) return;
    $.get(location.href.replace(/\?.*/, ''), { from: convos.current.end_time }, function(data) {
      var $ul = $(data).find('ul[data-network]');
      var $li = $ul.children('li:gt(0)');
      $('body').removeClass('loading');
      if (!$li.length) return;
      convos.current.end_time = parseFloat($ul.data('end-time'));
      convos.current.state = $ul.attr('data-state');
      $li.addToMessages();
    });
    convos.current.end_time = 0;
    $('body').addClass('loading');
  };

  convos.makeMessage = function(content) {
    var $m = $('<li class="message" data-sender="convos"></li>');
    $m.append('<img class="avatar" src="' + $.url_for('/image/avatar-convos.png') + '">');
    $m.append('<h3>convos</h3>');
    $m.append('<div class="content">' + content + '</div>');
    return $m;
  };

  var firstTimeConnected = convos.on('idle', function() {
    if ($('nav ul.conversations a[data-network="' + convos.current.network + '"]').length) return convos.unsubscribe('idle', firstTimeConnected);
    if (convos.current.state != 'connected') return;
    convos.unsubscribe('idle', firstTimeConnected);
    console.log('firstTimeConnected');
    convos.makeMessage('Hi ' + convos.current.nick + '. Welcome to ' + convos.current.network + '.').addToMessages();
    convos.makeMessage('Already know what channel you want to talk in? Press shift+enter or click the list icon next to the bell in the top menu, enter the channel name and click "Join" to add it to your connection.').addToMessages();
    convos.makeMessage('Otherwise, please hold on while I try to fetch the server channel list for you. (It could take a while)').addToMessages();
    convos.makeMessage('While you wait, try the help command: Type <b>/help</b> in the input field at the bottom on the page and hit enter. You can also use the &lt;tab> key to get suggestions for commands and nicks.').addToMessages();
    convos.send('/list');
    $(window).scrollTo('bottom');
  });

  $.fn.addToMessages = function(func) { // func = {prepend,append}
    return this.attachEventsToMessage().each(function() {
      var $message = $(this);
      var $messages = $('div.messages ul');
      var $same = $messages.children('li').not('.message-pending').eq(func == 'prepend' ? 0 : -1);
      var same_nick = $same.data('sender') || '';

      if ($message.hasClass('message') && $same.hasClass('message') && same_nick == $message.data('sender')) {
        (func == 'prepend' ? $same : $message).addClass('same-nick');
      }
      if (!$message.hasClass('hidden')) {
        $messages[func || 'append']($message);
      }

      $message.trigger('addedToMessages');
    });
  };

  $.fn.attachEventsToMessage = function() {
    this.find('a.internal').click(function(e) {
      e.preventDefault();
      $.pjax.click(e, { container: 'div.messages', fragment: 'div.messages' });
    });
    this.find('a.autocomplete').click(function(e) {
      var str = this.href.match(/.*complete:\/\/(.+)/);
      str = str ? str[1] : $(this).text();
      if (str.indexOf('/') != 0 && convos.input.val().length == 0) str += ':';
      if (convos.input.val().length) str = ' ' + str;
      e.preventDefault();
      convos.input.val(convos.input.val().replace(/\s+$/, '') + str + ' ').focus();
    });
    this.find('a[href^="http"].external').each(function(e) {
      var $a = $(this);
      $.get($.url_for('/oembed'), { url: this.href }, function(embed_code) {
        var $embed_code = $(embed_code);
        var at_bottom = convos.at_bottom;
        $a.closest('div').after($embed_code).closest('li').data('at_bottom', at_bottom);
        $embed_code.find('img').one('load', function() { if (at_bottom) $(window).scrollTo('bottom'); });
        $embed_code.find('.text-gist-github').each(function() {
          var self = this;
          window[self.id] = function(g) { self.innerHTML = g.div; if (at_bottom) $(window).scrollTo('bottom'); };
        });
        if (at_bottom) $(window).scrollTo('bottom');
      });
    });
    this.find('[data-avatar^="http"]').each(function(e) {
      $(this).replaceWith('<img src="' + $(this).attr('data-avatar') + '" class="avatar">');
    });

    this.find('a.go-forward-in-history').click(convos.goForwardInHistory);

    return this;
  };

  $.noCache = function(args) {
    args._ts = new Date().getTime();
    return args;
  };

  $.fn.scrollTo = function(pos) {
    if(pos === 'bottom') { $(this).scrollTop($('body').height()); }
    else { $(this).scrollTop(pos); }
    return this;
  };

  var focusFirst = function() {
    if (document.activeElement && $(document.activeElement).is(':input')) return;
    if (convos.input.length) return convos.input.focus();
    $('form input[type="text"]:visible').eq(0).focus();
  };

  var goBackwardInHistory = function() {
    if (!convos.current.start_time) return;
    var $loading = $('<li class="message notice"><div class="content">Loading historic messages...</div></li>');
    $.get(location.href.replace(/\?.*/, ''), { 'last-read-time': convos.current.last_read_time, to: convos.current.start_time }, function(data) {
      var $ul = $(data).find('ul[data-network]');
      var $li = $ul.children('li:lt(-1)');
      var height_before_prepend = $('body').height();
      $loading.remove();
      if (!$li.length) return;
      convos.current.start_time = parseFloat($ul.data('start-time'));
      $($li.get().reverse()).addToMessages('prepend');
      $(window).scrollTop($('body').height() - height_before_prepend);
    });
    $loading.addToMessages('prepend');
    convos.current.start_time = 0;
  };

  var initPjax = function() {
    $.pjax.defaults.maxCacheLength = 0; // Will refresh conversation when going back/forward, fixes #111
    $(document).on('pjax:timeout', function(e) { e.preventDefault(); });
    $(document).pjax('nav ul a', 'div.messages', { fragment: 'div.messages' });
    $(document).pjax('.sidebar-right a', 'div.messages', { fragment: 'div.messages' });

    $('div.messages').on('pjax:beforeReplace', function(xhr, options) { $('body').removeClass('loading'); });
    $('div.messages').on('pjax:beforeSend', function(xhr, options) { return !$(this).hasClass('no-pjax'); });
    $('div.messages').on('pjax:start', function(xhr, options) { $('body').addClass('loading'); });

    $('div.messages').on('pjax:success', function(e, data, status_text, xhr, options) {
      var $doc = data.match(/<\w/) ? $(data) : $('body');
      var $messages = $('div.messages ul'); // injected to the document using pjax

      convos.emit('conversation-loaded', $doc);

      convos.current.channels = {};
      convos.current.end_time = parseFloat($messages.attr('data-end-time'));
      convos.current.start_time = parseFloat($messages.attr('data-start-time'));
      convos.current.last_read_time = parseFloat($messages.attr('data-last-read-time'));
      convos.current.nick = $messages.attr('data-nick') || '';
      convos.current.network = $messages.attr('data-network') || 'convos';
      convos.current.state = $messages.attr('data-state');
      convos.current.target = $messages.attr('data-target') || '';
      convos.send(convos.isChannel(convos.current.target) ? '/names' : ''); // get nick list or open socket

      $messages.find('li').attachEventsToMessage();
      $doc.filter('form.sidebar').each(function() {
        $('form.sidebar').attr('action', this.action);
        $('form.sidebar ul').html($(this).find('ul:first').children());
      });
      $doc.filter('nav').each(function() { $('nav ul.conversations').html($(this).find('ul.conversations').children()); });

      if (location.href.indexOf('from=') > 0) {
        $messages.find('li:first').addClass('history-starting-point');
        goBackwardInHistory();
      }
      if (convos.current.nick) {
        convos.input.removeAttr('disabled');
        convos.input.attr('placeholder', 'What is on your mind, ' + convos.current.nick + '?');
      }
      else {
        convos.input.attr('disabled', 'disabled');
        convos.input.attr('placeholder', '');
      }

      if (!navigator.is_touch_device) focusFirst();
      if (data) $('body').hideSidebar();

      convos.at_bottom = true; // make "resize" scroll to bottom
      $(window).resize();
    });
  };

  $(document).ready(function() {
    $.ajaxSetup({ error: function(jqXHR, exception) { console.log('ajax: ' + this.url + ' failed: ' + exception); } });
    $.post($.url_for('/profile/timezone/offset'), { hour: new Date().getHours() });

    initPjax();

    $('body, input').bind('keydown', 'shift+return', function(e) {
      e.preventDefault();
      if (document.activeElement && $(document.activeElement).closest('.input').length) return $('nav a.goto-anything').trigger('tap');
      $(document).hideSidebar();
      convos.input.focus();
    });
    $('body, input').bind('keydown', 'alt+shift+a', function(e) { e.preventDefault(); $('nav a.goto-anything').trigger('tap'); });
    $('body, input').bind('keydown', 'alt+shift+s', function(e) { e.preventDefault(); $('nav a.notifications').trigger('tap'); });
    $('body, input').bind('keydown', 'alt+shift+d', function(e) { e.preventDefault(); $('nav a.sidebar').filter(':visible').trigger('tap'); });

    if (navigator.is_ios) {
      $('input, textarea')
        .on('click focus', function() { $('body').addClass('ios-input-focus'); $(window).scrollTo('bottom'); })
        .on('blur focusout', function() { $('body').removeClass('ios-input-focus'); });
    }

    $(window).on('resize', function(e) {
      var menu_width = 0;
      $('nav .right').add('nav ul.conversations a').each(function() { menu_width += $(this).outerWidth(); });
      $('nav a.goto-anything')[ menu_width > $('body').outerWidth() ? 'addClass' : 'removeClass' ]('overlapping');
      if (convos.at_bottom) $(window).scrollTo('bottom');
    });

    $(window).on('scroll', function(e) {
      convos.at_bottom = $(this).scrollTop() + $(this).height() > $('body').height() - convos.at_bottom_threshold;
      if ($(window).scrollTop() == 0) goBackwardInHistory();
    });

    // handle cmd://... url
    $(document).click(function(e) {
      var cmd = (e.target.href || '').match(/^cmd:\/\/(.*)/);
      if (!cmd) return;
      e.preventDefault();
      convos.send(decodeURI(cmd[1]));
      $('body').hideSidebar();
    });

    // clear notifications when showing notifications sidebar
    $('.notification-list').on('show', function(e) {
      var $n = $('nav a.notifications b');
      if ($n.text().length) $.post($.url_for('/chat/notifications/clear'));
      $n.text('');
    }).find('a').on('click', function(e) { $(this).parent('.unread').removeClass('unread'); })
  });

  $(window).load(function() {
    $('div.messages').trigger('pjax:success', [ '', 'success', {}, {} ]); // render initial div.messages
    if (!navigator.is_touch_device) focusFirst(); // need to focus even if we have no div.messages
  });
})(jQuery);
