;(function($) {
  window.convos = window.convos || {}

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

    var matcher = function(v) {
      if (dup[v]) return;
      if (offset && v.indexOf('/') === 0) return;
      if (!re.test(v)) return;
      dup[v] = suggestions.push(offset ? v + ' ' : v.indexOf('/') === 0 ? v : v + ': ');
    };

    $.each($('.messages h3 > a').get().reverse(), function() { matcher($(this).text()); });
    $.each(commands, function() { matcher("" + this); }); // "" = force String object to string primitive
    suggestions.push(val);
    console.log('makeSuggestions', e);

    this.before_suggestion = val.substr(0, offset);
    this.suggestions = suggestions;
    this.suggestions.i = -1;
  };

  $(document).ready(function() {
    $.get($.url_for('/chat/command-history'), $.noCache({}), function(data) {
      convos.input.get(0).history = data.unique();
      convos.input.get(0).history.i = convos.input.get(0).history.length;
    });

    convos.input = $('form.input input[autocomplete="off"]');
    convos.input.get(0).history = [];
    convos.input.get(0).history.i = 0;
    convos.input.removeAttr('disabled');
    convos.input.on('doubletap', autocompleter);
    convos.input.bind('keydown', function(e) {
      if (String.fromCharCode(e.which).match(/^[\w\u0400-\u04FF]$/)) this.suggestions = false; // match(printable character)
      if (e.which == 9) autocompleter.call(this, e); // tab
    });
    convos.input.bind('keydown', 'up', function(e) {
      e.preventDefault();
      if (this.history.i == 0) return;
      if (this.history.i == this.history.length) this.current_input_str = convos.input.val();
      convos.input.val(this.history[--this.history.i]);
    });
    convos.input.bind('keydown', 'down', function(e) {
      e.preventDefault();
      if (++this.history.i == this.history.length) return convos.input.val(this.current_input_str);
      if (this.history.i > this.history.length) return this.history.i = this.history.length;
      convos.input.val(this.history[this.history.i]);
    });
    convos.input.closest('form').on('submit', function(e) {
      e.preventDefault();
      convos.send(convos.input.val(), { 'data-convos.history': 1 });
      convos.input.val('');
    });
  });
})(jQuery);
