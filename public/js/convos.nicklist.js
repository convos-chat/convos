;(function($) {
  window.convos = window.convos || {}

  convos.nicks = {
    list: [],
    init: function($e) {
      $('form.sidebar ul li.nick.status').remove();
      $e.find('[data-nick]').each(function() { convos.nicks.joined($(this)); });
    },
    change: function($e) {
      var new_nick = $e.find('.nick').text();
      var old_nick = $e.find('.old').text();
      var re;

      if(old_nick == $messages.data('nick')) {
        re = new RegExp('\\b' + old_nick + '\\b', 'i');
        convos.input.attr('placeholder', convos.input.attr('placeholder').replace(re, new_nick));
        $messages.data('nick', new_nick);
      }
      else {
        convos.nicks.parted($e);
        convos.nicks.joined($e);
      }
    },
    joined: function($e) {
      var nick = $e.data('nick');
      var $ul = $('form.sidebar ul');
      var markup = '<li class="nick"><a href="cmd:///query ' + nick + '">' + nick + '</a></li>';

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
      convos.nicks.parted($e);
    },
    parted: function($e) {
      var nick = $e.data('nick');
      convos.nicks.list = $.grep(convos.nicks.list, function(n, i) { return n != nick; });
      $('form.sidebar a[href="cmd:///query ' + nick + '"]').parent().remove();
    },
    reset: function() {
      convos.nicks.list = [];
    }
  };
})(jQuery);
