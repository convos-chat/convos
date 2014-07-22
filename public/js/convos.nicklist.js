;(function($) {
  window.convos = window.convos || {}

  var template = function(nick) {
    return '<li class="nick"><a href="cmd:///query ' + nick + '">' + nick + '</a></li>';
  };

  convos.nicks = {
    list: [],
    init: function($e) { // convos.nicks.init($('<div><a href="cmd:///query batman_">@batman_</a></div>'));
      var $ul = $('form.sidebar ul');

      if (!convos.nicks.list.length) $ul.children('li.nick').remove();
      $e.find('.content a').each(function() { convos.nicks.list.push($(this).attr('href').split(' ')[1]); });
      $.each(convos.nicks.list.sortCaseInsensitive(), function(i, nick) { $ul.append(template(nick)); });
    },
    change: function($e) { // convos.nicks.change($('<div><span class="nick">batman</span><span class="old">batman_</span></div>'));
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
    joined: function($e) { // convos.nicks.joined($('<div><span class="nick">batman</span></div>'))
      var nick = $e.find('.nick').text();
      var $nicks = $('form.sidebar li[data-nick]');

      convos.nicks.list.push(nick);
      $nicks.each(function() {
        var $li = $(this);
        var n = $li.attr('data-nick');
        if (n < nick) return;
        $li.before(template(nick));
        return nick = false; // stop each()
      });

      if (nick) $li.after(template(nick));
    },
    quit: function($e) {
      convos.nicks.parted($e);
    },
    parted: function($e) { // convos.nicks.parted($('<div><span class="nick">batman</span></div>'))
      var nick = $e.find('.nick').text();
      $('form.sidebar li[data-nick="' + nick + '"]').remove();
    }
  };
})(jQuery);
