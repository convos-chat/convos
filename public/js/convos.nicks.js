;(function($) {
  window.convos = window.convos || {}

  convos.nicks = {
    list: [],
    init: function($e) {
      if (!$e.data('to_current')) return;
      $('form.sidebar ul li.nick.status').remove();
      $e.find('[data-nick]').each(function() { convos.nicks.joined($(this).data('to_current', true)); });
    },
    change: function($e) {
      if ($e.data('network') != convos.current.network) return;
      var new_nick = $e.find('.nick').text();
      var old_nick = $e.find('.old').text();
      var re;

      if (old_nick == convos.current.nick) {
        re = new RegExp('\\b' + old_nick + '\\b', 'i');
        convos.input.attr('placeholder', convos.input.attr('placeholder').replace(re, new_nick));
        convos.current.nick = new_nick;
      }
      else if($.grep(convos.nicks.list, function(n, i) { return n == old_nick; }).length) {
        convos.nicks.parted($e.data({ to_current: true, nick: old_nick }));
        convos.nicks.joined($e.data({ to_current: true, nick: new_nick }));
      }
    },
    joined: function($e) {
      if (!$e.data('to_current')) return;
      var nick = $e.data('nick');
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
    },
    quit: function($e) {
      if ($e.data('network') != convos.current.network) return;
      var nick = $e.data('nick');
      $e.data('to_current', !!$.grep(convos.nicks.list, function(n, i) { return n == nick; }).length);
      convos.nicks.list = $.grep(convos.nicks.list, function(n, i) { return n != nick; });
      $('form.sidebar a[href="cmd:///query ' + nick + '"]').parent().remove();
    },
    parted: function($e) {
      if (!$e.data('to_current')) return;
      var nick = $e.data('nick');
      convos.nicks.list = $.grep(convos.nicks.list, function(n, i) { return n != nick; });
      $('form.sidebar a[href="cmd:///query ' + nick + '"]').parent().remove();
    },
    reset: function() {
      convos.nicks.list = [];
    }
  };
})(jQuery);
