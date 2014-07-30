;(function($) {
  window.convos = window.convos || {}

  var history;
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

  var autocompleter = function(e) {
    e.preventDefault();
    if (!this.suggestions) makeSuggestions.call(this, e);
    this.suggestions.i = e.shiftKey ? this.suggestions.i - 1 : this.suggestions.i + 1;
    if (this.suggestions.i < 0) this.suggestions.i = this.suggestions.length - 1;
    if (this.suggestions.i == this.suggestions.length) this.suggestions.i = 0;
    this.value = this.before_suggestion + this.suggestions[this.suggestions.i];
  };

  var makeSuggestions = function(e) {
    var val = this.value;
    var offset = val.lastIndexOf(' ') + 1;
    var after = val.substr(offset);
    var re = new RegExp('^' + RegExp.escape(after), 'i');
    var dup = {};
    var suggestions = [];

    var matcher = function(v, force) {
      if (dup[v]) return;
      if (v == convos.current.nick && !force) return;
      if (offset && v.indexOf('/') === 0) return;
      if (!re.test(v)) return;
      dup[v] = suggestions.push(offset ? v + ' ' : v.indexOf('/') === 0 ? v : v + ': ');
    };

    $.each($('.messages h3 > a').get().reverse(), function() { matcher($(this).text()); });
    $('nav.bar a.conversation span').each(function() { matcher($(this).text()); });
    $.each(convos.nicks.list, function() { matcher("" + this); }); // "" = force String object to string primitive
    $.each(commands, function() { matcher("" + this); }); // "" = force String object to string primitive
    matcher(convos.current.nick, true);
    suggestions.push(after);
    console.log('makeSuggestions', e);

    this.before_suggestion = val.substr(0, offset);
    this.suggestions = suggestions;
    this.suggestions.i = -1;
  };

  history = [];
  history.i = 0;
  convos.addInputHistory = function(cmd) {
    history = history.concat(cmd).unique();
    history.i = history.length;
  };

  $(document).ready(function() {
    convos.input = $('form.input input[autocomplete="off"]');

    if (!convos.input.length) return;

    $.get($.url_for('/chat/command-history'), $.noCache({}), function(data) {
      convos.addInputHistory(data.unique());
    });

    convos.input.removeAttr('disabled');
    convos.input.on('doubletap', autocompleter);
    convos.input.bind('keydown', function(e) {
      if (String.fromCharCode(e.which).match(/^[ \b\w\u0400-\u04FF]$/)) this.suggestions = false; // match(printable character), space, backspace, word characters in ascii and utf8
      if (e.which == 9) autocompleter.call(this, e); // tab
    });
    convos.input.bind('keydown', 'up', function(e) {
      e.preventDefault();
      if (history.i == 0) return;
      if (history.i == history.length) this.current_input_str = convos.input.val();
      convos.input.val(history[--history.i]);
    });
    convos.input.bind('keydown', 'down', function(e) {
      e.preventDefault();
      if (++history.i == history.length) return convos.input.val(this.current_input_str);
      if (history.i > history.length) return history.i = history.length;
      convos.input.val(history[history.i]);
    });
    convos.input.closest('form').on('submit', function(e) {
      e.preventDefault();
      convos.send(convos.input.val(), { 'data-history': 1 });
      convos.input.val('');
    });
  });
})(jQuery);
