;(function($) {
  window.convos = window.convos || {};

  convos.nicks = { list: [] };

  var timeout = 30 * 1000;

  var add = function(nick) {
    var $ul = $('form.sidebar ul');
    var markup = '<li class="nick"><a href="cmd:///query ' + nick + '">' + nick + '</a></li>';

    if (!nick) return;

    $ul.find('li.nick').each(function() {
      var n = $(this).find('a').text();
      if (n == nick) return nick = false;
      if (n.toLowerCase() < nick.toLowerCase()) return;
      convos.nicks.list.push(nick);
      $(this).before(markup);
      return nick = false; // stop each()
    });

    if (nick) {
      convos.nicks.list.push(nick);
      $ul.append(markup);
    }
  };

  var remove = function(nick) {
    convos.nicks.list = $.grep(convos.nicks.list, function(n, i) { return n != nick; });
    $('form.sidebar a[href="cmd:///query ' + nick + '"]').parent().remove();
  };

  var updateNumberOfNicks = function() {
    $('form.sidebar ul li.participants span').text(convos.nicks.list.length);
  };

  convos.on('conversation-loaded', function($doc) {
    convos.nicks.list = [];
    updateNumberOfNicks();
  });

  convos.on('nick-change', function($message) {
    if ($message.data('network') != convos.current.network) return;
    var new_nick = $message.find('.nick').text();
    var old_nick = $message.find('.old').text();
    var re;

    if (old_nick == convos.current.nick) {
      re = new RegExp('\\b' + old_nick + '\\b', 'i');
      convos.input.attr('placeholder', convos.input.attr('placeholder').replace(re, new_nick));
      convos.current.nick = new_nick;
    }
    else if($.grep(convos.nicks.list, function(n, i) { return n == old_nick; }).length) {
      remove(old_nick);
      add(new_nick);
    }

    setTimeout(function() { $message.fadeOut(); }, timeout);
  });

  convos.on('nick-joined', function($message) {
    if (!$message.data('to_current')) return;
    add($message.data('nick'));
    updateNumberOfNicks();
    setTimeout(function() { $message.fadeOut(); }, timeout);
  });

  convos.on('nick-list', function($message) {
    if (!$message.data('to_current')) return;
    if (!convos.nicks.list.length && $('.messages li.message').length > 1) $message.data('to_current', false); // only show in conversation on manual "/list"
    $('form.sidebar ul li.nick.status').remove();
    $message.find('[data-nick]').each(function() { add($(this).data('nick')); });
    updateNumberOfNicks();
  });

  convos.on('nick-quit', function($message) {
    if ($message.data('network') != convos.current.network) return;
    var nick = $message.data('nick');
    $message.data('to_current', !!$.grep(convos.nicks.list, function(n, i) { return n == nick; }).length);
    remove(nick);
    updateNumberOfNicks();
    setTimeout(function() { $message.fadeOut(); }, timeout);
  });

  convos.on('nick-parted', function($message) {
    if (!$message.data('to_current')) return;
    remove($message.data('nick'));
    updateNumberOfNicks();
    setTimeout(function() { $message.fadeOut(); }, timeout);
  });

})(jQuery);
