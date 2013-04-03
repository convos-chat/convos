(function($) {
  var history = [];
  var history_index = 0;
  var commands = [
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
    initAutocomplete: function(list) {
      var autocomplete = commands.slice(0);
      $.each(list, function() { autocomplete.unshift(this); });
      this.data('autocomplete', autocomplete);
      log('initAutocomplete', list, autocomplete);
      return this;
    },
    addAutocomplete: function(list) {
      var autocomplete = this.data('autocomplete');
      methods.removeAutocomplete.call(this, list); // prevent duplicates
      $.each(list, function() { autocomplete.unshift(this); });
      log('addAutocomplete', list, autocomplete);
      return this;
    },
    removeAutocomplete: function(list, cb) {
      var autocomplete = this.data('autocomplete');
      $.each(list, function(i, needle) {
        $.each(autocomplete, function(i, command) {
          console.log(needle, command);
          if(command === needle) {
            autocomplete.splice(i, i + 1);
            if(cb) cb.call(this.get(0), needle);
          }
        });
      });
      log('removeAutocomplete', list, autocomplete);
      return this;
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

      self.data('tabbing', { tabbed: -1 });
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
        var autocomplete = this.data('autocomplete');
        var offset = val.lastIndexOf(' ') + 1;
        var re = new RegExp('^' + val.substr(offset));

        data.offset = offset;
        data.matched = $.grep(autocomplete, function(v, i) {
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
