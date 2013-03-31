(function($) {
  var history = [];
  var history_index = 0;
  var autocomplete = [
    '/join #',
    '/query #',
    '/msg ',
    '/me ',
    '/nick ',
    '/part ',
    '/whois '
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
      this.bind('keydown','up',function(e) {
        e.preventDefault();

        if(history.length === 0) return;
        if(history_index == history.length) self.data('initial_value', this.value);
        if(--history_index < 0) history_index = 0;
        this.value = history[history_index];

      });
      this.bind('keydown','down',function(e) {
        e.preventDefault();
        if(history.length === 0) return;
        if(++history_index >= history.length) history_index = history.length;
        this.value = history[history_index] || self.data('initial_value') || '';
      });

      this.bind('keydown','tab',function(e) {
        e.preventDefault();
        this.value = methods.tabbing.call($(this), this.value);

      });
      this.bind('keydown','return',function(e){
        if(this.value.length === 0) return e.preventDefault(); // do not send empty commands
        history.push(this.value);
        history_index = history.length;
      });
      this.on('keydown',function(e) {
        methods.tabbing.call($(this), false);
      });

      return this;
    },
    tabbing: function(val) {
      var complete, tabbed;

      if(val === false) {
        this.removeData('tabbed̈́');
        return this;
      }
      if(this.hasData('tabbed̈́')) {
        var offset = val.lastIndexOf(' ') + 1;
        var re = new RegExp('^' + val.substr(offset));

        autocomplete_offset = offset;
        this.matched = $.grep(autocomplete, function(v, i) {
                        return offset ? v.indexOf('/') === -1 && re.test(v) : re.test(v);
                       });
        tabbed = -1; // ++ below will make this 0 the first time
      }

      tabbed = this.data('tabbed');
      if(this.matched.length === 0) return val;
      if(++tabbed >= this.matched.length) tabbed = 0;
      this.dat('tabbed', tabbed);
      complete = val.substr(0, autocomplete_offset) + this.matched[tabbed];
      if(complete.indexOf('/') !== 0 && val.indexOf(' ') === -1) complete +=  ': ';
      if(this.matched.length === 1) this.matched = []; // do not allow more tabbing on one hit

      return complete;
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
