(function($) {
  var history = [];
  var history_index = 0;
  var autocomplete = [
    '/join #',
    '/query ',
    '/msg ',
    '/me ',
    '/nick ',
    '/part ',
    '/topic ',
    '/close',
    '/reconnect',
    '/whois ',
    '/help'
  ];

  var methods = {
    autoCompleteNicks: function(data) {
      if(data.old_nick) {
        var needle = data.old_nick;
        autocomplete = $.grep(autocomplete, function(v, i) {
          return v != needle;
        });
      }
      if(data.new_nick) {
        methods.autoCompleteNicks.call(this, { old_nick: data.new_nick });
        autocomplete.unshift(data.new_nick);
      } else if(data.nick) {
        methods.autoCompleteNicks.call(this, { old_nick: data.nick });
        autocomplete.unshift(data.nick);
      }
    },
    inputKeys: function() {
      var self = this;

      self.bind('keydown', 'up', function(e) {
        e.preventDefault();
        if(history.length === 0) return;
        if(history_index == history.length) self.data('initial_value', self.value);
        if(--history_index < 0) history_index = 0;
        this.value = history[history_index];
      });
      self.bind('keydown', 'down', function(e) {
        e.preventDefault();
        if(history.length === 0) return;
        if(++history_index >= history.length) history_index = history.length;
        this.value = history[history_index] || self.data('initial_value') || '';
      });
      self.bind('keydown', 'return', function(e) {
        if(this.value.length === 0) return e.preventDefault(); // do not send empty commands
        history.push(this.value);
        history_index = history.length;
      });

      self.data('tabbing', { tabbed: -1, autocomplete: autocomplete });
      self.on('keydown', function(e) { return methods.tabbing.call(self, e); });

      return self;
    },
    tabbing: function(e) {
      var data = this.data('tabbing');
      var val = this.val();

      if(e.keyCode === 9) {
        if(data.tabbed === -1) data.offset = val.length;
      }
      else {
        if(data.tabbed >= 0) data.tabbed = -1;
        return true;
      }

      log('tabbing <', e.keyCode, this.data('tabbing'));
      if(data.tabbed === -1) {
        var offset = val.lastIndexOf(' ') + 1;
        var re = new RegExp('^' + val.substr(offset));

        data.offset = offset;
        data.matched = $.grep(data.autocomplete, function(v, i) {
          return offset ? v.indexOf('/') === -1 && re.test(v) : re.test(v);
        });
      }

      if(data.matched.length === 0) return false;
      if(++data.tabbed >= data.matched.length) data.tabbed = 0;
      data.complete = val.substr(0, data.offset) + data.matched[data.tabbed];
      if(data.complete.indexOf('/') !== 0 || val.indexOf(' ') == val.length) data.complete += ': ';

      log('tabbing >', this.data('tabbing'));
      this.val(data.complete);
      return false;
    }
  };

  $.fn.chatInput = function(method) {
    if(!method) {
      methods['inputKeys'].apply(this, Array.prototype.slice.call(arguments, 1));
      this.focus();
      return this;
    }
    else if(methods[method]) {
      return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
    }
    else {
      $.error('Method ' + method + ' does not exist on jQuery.chatInput');
    }
  };
})(jQuery);
