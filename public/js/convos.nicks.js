;(function($) {
  window.convos = window.convos || {};

  convos.current = convos.current || {};
  convos.current.nicks = {};

  var timeout = 30 * 1000;

  var add = function(nick, fast) {
    var markup = '<li class="nick" data-nick="' + nick.toLowerCase() + '"><a href="cmd:///query ' + nick + '">' + nick + '</a></li>';
    convos.current.nicks[nick] = true;
    $('form.sidebar ul').append(markup);
    if (!fast) sort();
  };

  var numberOfNicks = function() {
    return Object.keys(convos.current.nicks).length;
  };

  var remove = function(nick) {
    delete convos.current.nicks[nick];
    $('form.sidebar a[href="cmd:///query ' + nick + '"]').parent().remove();
  };

  var sort = function() {
    var $ul = $('form.sidebar ul');
    $ul.append(
      $ul.find('li.nick').remove().get().sort(function(a, b) {
        if (a.dataset.nick > b.dataset.nick) return 1;
        if (a.dataset.nick < b.dataset.nick) return -1;
        return 0;
      })
    );
  };

  convos.on('conversation-loaded', function($doc) {
    convos.current.nicks = {};
    $('form.sidebar ul li.participants span').text(0);
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
    else if(convos.current.nicks[old_nick]) {
      remove(old_nick);
      add(new_nick);
    }
  });

  convos.on('nick-joined', function($message) {
    if (!$message.data('to_current')) return;
    add($message.get(0).dataset.nick);
    $('form.sidebar ul li.participants span').text(numberOfNicks());
  });

  convos.on('nick-kicked', function($message) {
    if ($message.data('network') != convos.current.network) return;
    var nick = $message.data('nick');
    $message.data('to_current', !!$.grep(convos.nicks.list, function(n, i) { return n == nick; }).length);
    remove(nick);
    updateNumberOfNicks();
  });

  convos.on('nick-list', function($message) {
    if (!$message.data('to_current')) return;
    if (!numberOfNicks() && $('.messages li.message').length > 1) $message.data('to_current', false); // only show in conversation on manual "/list"
    $('form.sidebar ul li.nick.status').remove();
    $message.find('[data-nick]').each(function() { add(this.dataset.nick, true); });
    $('form.sidebar ul li.participants span').text(numberOfNicks());
    sort();
  });

  convos.on('nick-quit', function($message) {
    if ($message.data('network') != convos.current.network) return;
    var nick = $message.get(0).dataset.nick;
    $message.data('to_current', !!$.grep(convos.current.nicks, function(n, i) { return n == nick; }).length);
    remove(nick);
    $('form.sidebar ul li.participants span').text(numberOfNicks());
  });

  convos.on('nick-parted', function($message) {
    if (!$message.data('to_current')) return;
    remove($message.get(0).dataset.nick);
    $('form.sidebar ul li.participants span').text(numberOfNicks());
  });

})(jQuery);
