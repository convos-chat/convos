Structure.registerModule('Wirc', {
  base_url: window.location.href,
  test: function() {
    loadScript(Wirc.base_url + '/js/test.js', function() {
      Wirc.Test.run();
    });
  }
});

Structure.registerModule('Wirc.Notifier', {
  window_has_focus: true,
  original_title: document.title,
  popup: function(icon, title, msg) {
    if(this.window_has_focus) return;
    if(this.notifier) this.notifier.createNotification(icon || '', title, msg || '').show();
  },
  title: function(t) { // change title and make the tab flash (at least in chrome)
    if(this._t) clearTimeout(this._t);
    if(this.window_has_focus) return;
    if(t) this._title = t;
    document.title = document.title == this._title || document.title == this.original_title ? this._title + ' - ' + this.original_title : this._title;
    this._t = setTimeout(this.title, 2000);
  },
  requestPermission: function() {
    webkitNotifications.requestPermission(function() {
      if(!webkitNotifications.checkPermission()) Wirc.Notifier.notifier = notifier;
    });
  },
  init: function() {
    var self = this;

    if(!window.webkitNotifications) {
      // cannot show notifications
    }
    else if(webkitNotifications.checkPermission()) {
      // cannot run requestPermission() without a user action, such as mouse click or key down
      $(document).one('keydown', function() { Wirc.Notifier.requestPermission(); });
    }
    else {
      this.notifier = webkitNotifications;
    }

    $(window).blur(function() {
      self.window_has_focus = false;
    });
    $(window).focus(function() {
      self.window_has_focus = true;      
      this._t = setTimeout(function() { document.title = self.original_title; }, 4000);
    });

    return this;
  }
}); // End Wirc.Notify

Structure.registerModule('Wirc.Chat', {
  makeTargetId: function(cid,target) {
    return 'target_' + ( target ? cid+"_"+target.replace(/\W/g, '') : cid);
  },
  modifyChannelList: function(data) { // TODO: return channel names
    var $channel = $('#' + this.makeTargetId(data.cid, data.joined || data.parted));

    if(data.parted)
      $channel.remove();

    if(data.joined && !$channel.length)
      $(tmpl('new_channel_template', data)).insertAfter('#connection_list_' + data.cid + ' .channel:last');
  },
  modifyConversationlist: function(data) {
    var $conversation = $('#' + this.makeTargetId(data.cid, data.nick));

    if(!$conversation.length)
      $(tmpl('new_conversation_template', data)).appendTo('#connection_list_' + data.cid);
  },
  displayUnread: function(data) {
    var id =  this.makeTargetId(data.cid, data.target);
    var $badge = $('#' + id + ' .badge');
    $badge.text(parseInt($badge.text(), 10) + 1 ).show();
    if(data.highlight) $badge.addClass('badge-important');
  },
  print: function(data) {
    var at_bottom = $(window).scrollTop() + $(window).height() >= $('body').height() - 30; // need to calculate at_bottom before appending a new element
    var $messages = this.$messages;

    if(data.status) {
      if(data.status == this.status) return; // do not want duplicate status messages
      if(data.message) $messages.append(tmpl('server_status_template', data));
      this.status = data.status;
    }
    else if(data.cid === this.connection_id) {
      if( data.new_nick ) {
        $messages.append(tmpl('nick_change_template', data));
      }
      else if(data.joined === this.target) {
        $messages.append( $(tmpl('nick_joined_template', data)) );
      }
      else if(data.parted === this.target && data.nick !== this.nick) {
        $messages.append( $(tmpl('nick_parted_template', data)) );
      }
      else if(data.template && data.target == this.target || data.nick == this.target) {
        $messages.append(tmpl(data.template, data));
      }
    }
    else if(data.whois) {
      $messages.append( $(tmpl('whois_template', data)) );
    }
    else if(data.whois_channels) {
      $messages.append( $(tmpl('whois_channels_template', data)) );
    }
    
    if(data.message) {
      this.displayUnread(data);
    }

    if(at_bottom) {
      this.do_not_load_history = true;
      $('html, body').scrollTop($('body').height());
      this.do_not_load_history = false;
    }
  },
  parseIrcInput: function(d) {
    var data = $.parseJSON(d);

    if(data.message) {
      var action = data.message.match(/^\u0001ACTION (.*)\u0001$/);
      if(action) data.message = action[1];
      data.highlight = data.message.match("\\b" + this.nick + "\\b") ? 1 : 0;
      data.message = data.message.replace(/</i, '&lt;').replace(/\b(\w{2,5}:\/\/\S+)/g, '<a href="$1" target="_blank">$1</a>');
      data.template = action ? 'action_message_template' : 'message_template';
    }

    if(data.timestamp) {
      data.timestamp = new Date(parseInt(data.timestamp * 1000, 10));
    }

    data.class_name = data.nick === this.nick ? 'me'
                    : data.highlight          ? 'focus'
                    :                           '';

    return data;
  },
  receiveData: function(e) {
    if(window.console) console.log('[websocket] > ' + e.data);
    var data = Wirc.Chat.parseIrcInput(e.data);

    // notification handling
    if(data.highlight) {
      this.notifier.popup('', 'New mention by ' + data.nick + ' in ' + data.target, data.message);
      this.notifier.title('New mention by ' + data.nick + ' in ' + data.target);
    }
    else if(data.target === this.nick) {
      this.notifier.popup('', 'New message from ' + data.nick, data.message);
      this.notifier.title('New message from ' + data.nick);
    }

    // action handling
    if(data.nick === this.nick && (data.joined || data.parted)) {
      this.modifyChannelList(data);
    }
    else if(data.target === this.nick && data.target !== this.target && this.target !== this.nick) {
      this.modifyConversationlist(data);
    }
    else if(data.new_nick && this.nick === data.old_nick) this.nick = this.new_nick;

    this.input.autoCompleteNicks(data);

    this.print(data);
  },
  sendData: function(data) {
    try {
      this.websocket.send(JSON.stringify(data));
      if(window.console) console.log('[websocket] < ' + JSON.stringify(data));
    } catch(e) {
      if(window.console) console.log('[websocket] ! ' + e);
      this.print({ message: '[ws] < (' + data + '): ' + e });
    }
  },
  onScroll: function() {
    if(this.do_not_load_history) return;
    if(this.$history_indicator || $(window).scrollTop() !== 0) return;
    var self = this;
    var height_before_load = $('body').height();
    var url = Wirc.base_url + '/history/' + (++self.history_index);
    self.$history_indicator = $('<div class="alert alert-info">Loading previous conversations...</div>');
    self.$messages.before(self.$history_indicator);
    if(window.console) console.log('[Wirc.Chat.onScroll] ' + url);
    $.get(url, function(data) {
      if($(data).find('*').length) {
        self.$messages.prepend(data);
        self.$history_indicator.remove();
        self.$history_indicator = false;
        $(window).scrollTop($('body').height() - height_before_load);
      }
      else {
        self.do_not_load_history = true;
        self.$history_indicator.removeClass('alert-info').text('End of conversation log.');
        setTimeout(function() { self.$history_indicator.fadeOut('slow'); }, 2000);
      }
    });
  },
  changeChannel: function() {
    var self = this;
    self.$messages = $('.messages ul');
    Wirc.Chat.connection_id = $('#chat-messages').attr('data-cid');
    Wirc.Chat.nick = $('#chat-messages').attr('data-nick');
    Wirc.Chat.target = $('#chat-messages').attr('data-target');
    $.each($('#chat-messages').attr('data-nicks').split(','), function(i, v) {
      if(v == this.nick) return;
      self.input.autoCompleteNicks({ new_nick: v.replace(/^\@/, '') });
    });
    $('.server li').removeClass('active');
    var $target=$('#' + Wirc.Chat.makeTargetId(Wirc.Chat.connection_id,Wirc.Chat.target));
    $target.addClass('active');
    $target.find('.badge').remove();
    $('html, body').scrollTop($('body').height());
  },
  generic: function() {
    var self = this;
    var $conversation_list = $('.conversation-list');
    var $window = $(window);

    self.notifier = Wirc.Notifier.init();

    $('a.show-hide').fastclick(function() {
      $conversation_list.toggleClass('hidden open');
      return false;
    });
    $window.resize(function() {
      if($window.width() < 767) {
        if(!$conversation_list.hasClass('open')) $conversation_list.addClass('hidden');
      }
      else {
        $conversation_list.removeClass('hidden');
      }
    }).resize();
  },
  init: function() {
    var self = this;

    self.input = Wirc.Chat.Input.init($('.chat form input[type="text"]'));
    self.generic();
    self.changeChannel();
    self.history_index = 1;
    self.$messages = $('.messages ul');
    self.websocket = new ReconnectingWebSocket(Wirc.base_url.replace(/^http/, 'ws') + '/socket');
    self.websocket.onopen = function() { self.sendData({ cid: self.connection_id, target: self.target }); };
    self.websocket.onmessage = self.receiveData;

    self.input.submit = function(e) {
      self.sendData({ cid: self.connection_id, target: self.target, cmd: this.$input.val() });
      this.$input.val(''); // TODO: Do not clear the input field until echo is returned?
      return false;
    };
    self.pjax = Wirc.Chat.Pjax.init('.server a', '#conversation');
    

    setTimeout(function() {
      $('html, body').scrollTop($('body').height());
      $(window).on('scroll', self.onScroll);
    }, 400);

    $(window).on('scroll', Wirc.Chat.onScroll);
    if(window.console) console.log('[Wirc.Chat.init] ', self);

    return self;
  }
}); /* End Structure.registerModule('Wirc.Chat') */

Structure.registerModule('Wirc.Chat.Pjax', {
  setup_activity: function() {
    $(document).on('pjax:send', function() {
      $('#loading').show()
      Wirc.Chat.input.$input.css('background', 'url(/image/loading.gif) no-repeat');
      self.placeholder=Wirc.Chat.input.$input.attr('placeholder');
      Wirc.Chat.input.$input.attr('placeholder','');
      Wirc.Chat.input.$input.prop('disabled',true);
    });
    $(document).on('pjax:complete', function() {
      Wirc.Chat.input.$input.css('background', '');
      Wirc.Chat.input.$input.attr('placeholder',self.placeholder);
      Wirc.Chat.input.$input.prop('disabled',false);
      Wirc.Chat.input.$input.focus();
    });
    $(document).on('pjax:timeout', function(event) {
      // Prevent default timeout redirection behavior
      event.preventDefault()
    });
    
  },
  init: function(link_selector,target) {
    var self = this;
    $(document).pjax(link_selector,target);
    $(target).on('pjax:success',function(e){
      Wirc.Chat.changeChannel();
    });
    self.setup_activity()
  }
  
}); /* End Structure.registerModule('Wirc.Pjax') */


Structure.registerModule('Wirc.Chat.Input', {
  autocomplete: [
    '/join #',
    '/msg ',
    '/me ',
    '/nick ',
    '/part ',
    '/whois '
  ],
  autoCompleteNicks: function(data) {
    if(data.old_nick) {
      var needle = data.old_nick;
      this.autocomplete = $.grep(this.autocomplete, function(v, i) {
        return v != needle;
      });
    }
    if(data.new_nick) {
      this.autoCompleteNicks({ old_nick: data.new_nick });
      this.autocomplete.unshift(data.new_nick);
    } else if(data.nick) {
      this.autoCompleteNicks({ old_nick: data.nick });
      this.autocomplete.unshift(data.nick);
    }
  },
  tabbing: function(val) {
    var complete;

    if(val === false) {
      delete this.tabbed;
      return this;
    }
    if(typeof this.tabbed === 'undefined') {
      var offset = val.lastIndexOf(' ') + 1;
      var re = new RegExp('^' + val.substr(offset));

      this.autocomplete_offset = offset;
      this.matched = $.grep(this.autocomplete, function(v, i) {
                      return offset ? v.indexOf('/') === -1 && re.test(v) : re.test(v);
                     });
      this.tabbed = -1; // ++ below will make this 0 the first time
    }

    if(this.matched.length === 0) return val;
    if(++this.tabbed >= this.matched.length) this.tabbed = 0;
    complete = val.substr(0, this.autocomplete_offset) + this.matched[this.tabbed];
    if(complete.indexOf('/') !== 0 && val.indexOf(' ') === -1) complete +=  ': ';
    if(this.matched.length === 1) this.matched = []; // do not allow more tabbing on one hit

    return complete;
  },
  keydownCallback: function(e) {
    var self = this;
    return function(e) {
      switch(e.keyCode) {
        case 38: // up
          e.preventDefault();
          if(self.history.length === 0) return;
          if(self.history_index == self.history.length) self.initial_value = this.value;
          if(--self.history_index < 0) self.history_index = 0;
          this.value = self.history[self.history_index];
          break;

        case 40: // down
          e.preventDefault();
          if(self.history.length === 0) return;
          if(++self.history_index >= self.history.length) self.history_index = self.history.length;
          this.value = self.history[self.history_index] || self.initial_value || '';
          break;

        case 9: // tab
          e.preventDefault();
          this.value = self.tabbing(this.value);
          break;

        case 13: // return
          if(this.value.length === 0) return e.preventDefault(); // do not send empty commands
          self.history.push(this.value);
          self.history_index = self.history.length;
          break;

        default:
          self.tabbing(false);
          delete self.initial_value;
      }
    };
  },
  focus: function() {
    this.$input.focus();
  },
  init: function(input_selector) {
    var self = this;
    var $input = $(input_selector);

    self.history = [];
    self.history_index = 0;
    self.$input = $input;

    $input.keydown(self.keydownCallback());
    $input.parents('form').submit(function(e) { return self.submit(e); });
    self.focus();
    $(window).focus(function() { console.log('OOH'); self.focus(); });

    return self;
  }
}); // End Wirc.Chat.Input

(function($) {
  $(document).ready(function() {
    Wirc.base_url = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');

    /* toggle dropdown */
    $('a.dropdown-toggle').click(function() {
      var $e = $(this);
      $e.parents('.dropdown:first').toggleClass('open');
      $(window).one('click', function(e) {
        if($(e.target).parents('.dropdown:first').length) return true;
        $e.parents('.dropdown:first').removeClass('open');
        return false;
      });
      return false;
    });
    return $('body.chat .messages').length ? Wirc.Chat.init() : Wirc.Chat.generic();
  });
})(jQuery);

/*
 * Flash fallback for websocket
 *
if(!('WebSocket' in window)) {
  document.write([
    '<script type="text/javascript" src="' + Wirc.base_url + '/js/swfobject.js"></script>',
    '<script type="text/javascript" src="' + Wirc.base_url + '/js/FABridge.js"></script>',
    '<script type="text/javascript" src="' + Wirc.base_url + '/js/web_socket.js"></script>'
  ].join(''));
}
if(WebSocket.__initialize) {
  // Set URL of your WebSocketMain.swf here:
  WebSocket.__swfLocation = Wirc.base_url + '/js/WebSocketMain.swf';
}
*/
