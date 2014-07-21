;(function($) {
  window.convos = window.convos || {}

  var template = function(nick) {
    return '<li class="nick"><a href="cmd:///query ' + nick + '">' + nick + '</a></li>';
  };

  convos.nicklist = {
    init: function($e) { // convos.nicklist.init($('<div><a href="cmd:///query batman_">@batman_</a></div>'));
      var $ul = $('form.sidebar ul');
      var nicks = $e.find('.content a').map(function() { return $(this).attr('href').split(' ')[1]; }).get();
      var senders = {};

      $ul.children('li.nick').remove();
      $.each(nicks.sortCaseInsensitive(), function(i, nick) { $ul.append(template(nick)); });
    },
    change: function($e) { // convos.nicklist.change($('<div><span class="nick">batman</span><span class="old">batman_</span></div>'));
      var new_nick = $e.find('.nick').text();
      var old_nick = $e.find('.old').text();
      var re;

      if(old_nick == $messages.data('nick')) {
        re = new RegExp('\\b' + old_nick + '\\b', 'i');
        convos.input.attr('placeholder', convos.input.attr('placeholder').replace(re, new_nick));
        $messages.data('nick', new_nick);
      }
      else {
        convos.nicklist.parted($e);
        convos.nicklist.joined($e);
      }
    },
    joined: function($e) { // convos.nicklist.joined($('<div><span class="nick">batman</span></div>'))
      var nick = $e.find('.nick').text();
      var $nicks = $('form.sidebar li[data-nick]');

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
      convos.nicklist.parted($e);
    },
    parted: function($e) { // convos.nicklist.parted($('<div><span class="nick">batman</span></div>'))
      var nick = $e.find('.nick').text();
      $('form.sidebar li[data-nick="' + nick + '"]').remove();
    }
  };
})(jQuery);
