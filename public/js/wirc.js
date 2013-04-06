(function($) {
  var input_selector = '.chat form input[type="text"]';
  var messages_selector = '#messages ul';
  var at_bottom = true;
  var websocket = {};
  var history_offset, conversation_name, $conversation;

  var methods = {
    init: function() {
      websocket = new ReconnectingWebSocket($.url_for('socket').replace(/^http/, 'ws'));
      websocket.onmessage = methods.receiveData;
      websocket.onclose = function() { websocket.is_open = false; };
      websocket.onopen = function() { websocket.is_open = true; };
      conversation_name = $('#navbar .brand').text();

      methods.changeConversation();
      methods.initNavbar();
      methods.initPjax();
      methods.initShortcuts();
      notifier.init();

      $('#connection_list > div, #nick_list .nav').disableOuterScroll();

      $('.embed img').live('click', function() { $(this).remove(); });
      $(input_selector).chatInput().parents('form').submit(methods.onSubmit);

      setTimeout(function() {
        $(window).scrollToBottom().on('scroll', methods.onScroll);
      }, 300);

      log('Wirc.Chat.init() success');
      return this;
    },
    initNavbar: function() {
      var $connection_list = $('#connection_list > .dropdown-menu');
      var hide = function(e) {
        e.preventDefault();
        $connection_list.hide().parent().hide();
        $('#navbar').find('a').parent('li').removeClass('open');
        $(input_selector).focus();
      };
      var show = function(e) {
        var $li = $(this).parent('li:first');
        hide.call(this, e);
        $connection_list.show().parent().show();
        $li.addClass('open');
      };

      $('#navbar .brand').click(function(e) {
        methods.sendData('/topic');
        return false;
      });

      $('#navbar .unread-menu').click(function(e) {
        if($(this).parent('li:first').hasClass('open')) return hide.call(this, e);
        $connection_list.find('.channel, .conversation').each(function() {
          var $b = $(this).find('.badge');
          if(!$b.hasClass('badge-important')) $(this).hide();
          else if($b.text() == '0') $(this).hide();
        });
        show.call(this, e);
        return false;
      });
      $('#navbar .chat-menu').click(function(e) {
        if($(this).parent('li:first').hasClass('open')) return hide.call(this, e);
        $connection_list.find('.channel, .conversation').show();
        show.call(this, e);
        return false;
      });
    },
    initPjax: function() {
      $(document).on('pjax:send', function(event) {
        statusIndicator('show', 'Loading...');
      });
      $(document).on('pjax:timeout', function(event) {
        event.preventDefault(); // Prevent default timeout redirection behavior
      });
      $('#messages > div').on('pjax:end', function(e) {
        statusIndicator('fadeOut');
        methods.changeConversation(e);
      });
      $(document).pjax('#connection_list a', '#messages > div');
    },
    initShortcuts: function() {
      var guard, $active, $e;
      var moveToConversation = function(e, selector) {
        if(selector) {
          $e = $('#navbar ' + selector);
          if($active || !$e.parent().hasClass('open')) $e.click();
          $active = $('#connection_list li.active').focus();
        }
        else if(!$active) {
          return;
        }

        e.preventDefault();
        $e = $active;
        guard = 200;

        if($e.filter(':visible').length === 0) {
          $e = $('#connection_list li:first');
          e.keyCode = 40;
        }

        do {
          $e = e.keyCode === 40 ? $e.next() : e.keyCode === 38 ? $e.prev() : $e;
          if(!--guard) break;
        } while($e.length && !$e.filter(':visible').length);
        if($e.length) $active = $e;
        $active.find('a').focus();
      };

      $(input_selector).focus(function() { $active = false; });

      $('input, body')
      .bind('keydown', 'shift+return', function(e) {
        e.preventDefault();
        $(input_selector).focus();
      })
      .bind('keydown', 'ctrl+m', function(e) { moveToConversation.call(this, e, '.unread-menu'); })
      .bind('keydown', 'ctrl+shift+m', function(e) { moveToConversation.call(this, e, '.chat-menu'); })
      .bind('keydown', 'up', moveToConversation)
      .bind('keydown', 'down', moveToConversation)
      ;
    },
    activeTarget: function(escaped) {
      var target = $conversation.attr('id').replace(/^conversation_/, '');
      return escaped ? target.replace(/:/g, '\\:') : target;
    },
    changeConversation: function(e) {
      var $target = e ? $(e.relatedTarget) : false;
      var $input = $(input_selector);
      var $nick_list = $('#nick_list ul:first');
      var li = [];

      $conversation = $('#messages ul:first');
      $input.chatInput('initAutocomplete');
      $(window).scrollToBottom();
      $('#connection_list li').removeClass('active');
      $('#target_' + methods.activeTarget(1)).addClass('active').find('.badge').text('0').removeClass('badge-important').hide();

      $.each($conversation.attr('data-nicks').split(','), function(i, nick) {
        $input.chatInput('addAutocomplete', nick.replace(/\@/g, ''));
        li.push('<li><a href="#">' + nick + '</a></li>');
      });

      $nick_list.html(li.join('')).find('a').click(function() { console.log(this); return false; });
      history_offset = $conversation.attr('data-offset');
      methods.unread('init');

      var tid = setInterval(function() {
        if(!websocket.is_open) return;
        methods.sendData('/topic');
        clearInterval(tid);
      }, 200);

      if($target) {
        conversation_name = $target.children('span:first').text();
        $('#navbar .brand').text(conversation_name);
      }

      log('changeConversation', $conversation.attr('id'));
    },
    printMessage: function(target) {
      if(target == 'any') target = methods.activeTarget(1); // special server messages
      if($('#conversation_' + target).length) {
        $(messages_selector).append(this);
        if(this.hasClass('nick-joined'))
          $(input_selector).chatInput('addAutocomplete', this.attr('data-nick'));
        else if(this.hasClass('nick-parted'))
          $(input_selector).chatInput('removeAutocomplete', this.attr('data-nick'));
        if(at_bottom)
          $(window).scrollToBottom();
        this.find('img').one('load', function() {
          if(at_bottom) $(window).scrollToBottom();
        });
      }
      else if(this.hasClass('message')) {
        methods.unread(this.hasClass('highlight') ? 'important' : 'normal', target);
      }
    },
    receiveData: function(e) {
      var $data = $(e.data);
      var target = $data.attr('data-target').replace(/:/g, '\\:');
      var $target = $('#target_' + target);
      var channel = /:23(.+)/.exec(target); // ":23" = "#"
      var txt;

      // notification handling
      if($data.hasClass('highlight')) {
        var sender = $data.attr('data-sender');
        var what = channel ? 'mentioned you in #' + channel[1] : 'sent you a message';
        notifier.popup([sender, what].join(' '), $data.find('.content').text(), '');
      }

      // action handling
      if($data.hasClass('add-conversation') || $data.hasClass('remove-conversation')) {
        var p = $data.hasClass('add-conversation') ? $data.attr('data-target') : $data.attr('data-target').replace(/:.*/, '');
        statusIndicator('show', 'Loading...');
        return $.get($.url_for('v1', p, 'connection-list'), function(data) {
          var $data = $(data);
          var target = $data.attr('id').replace(/:/g, '\\:');
          $('#' + target).replaceWith($data);
          $('#' + target).find('li.active > a').click();
        });
      }
      else if($data.hasClass('nick-change')) {
        $(input_selector).chatInput(
          'replaceAutocomplete',
          $data.attr('data-old-nick'), $data.attr('data-nick'),
          function() { target = 'any'; }
        );
      }
      else if($data.hasClass('topic')) {
        var text = [ conversation_name, $data.find('span:eq(1)').text() ].join(': ');
        $('#navbar .brand').text(text).attr('title', text);
      }

      methods.printMessage.call($data, target);
    },
    sendData: function(msg) {
      try {
        var $data = $('<div data-target="' + methods.activeTarget() + '">' + msg + '</div>').wrap('<div>').parent();
        websocket.send($data.html());
      } catch(e) {
        statusIndicator('show', e);
      }
    },
    unread: function(action, target) {
      if(action == 'init') {
        var method, n = 0;
        $('#connection_list .badge').each(function() {
          n += parseInt($(this).text(), 10);
        });
        $('#navbar .badge-unimportant').text(n);
        $('#navbar .badge-important').text(0); // TODO: This should be calculated like unimportant
      }
      else {
        var $badge = $('#target_' + target + ' .badge');
        $badge.text(parseInt($badge.text(), 10) + 1).show();
        if(action == 'important') {
          $badge.addClass('badge-important');
          $badge = $('#navbar .badge-important');
          $badge.text(parseInt($badge.text(), 10) + 1);
        }
        else {
          $badge = $('#navbar .badge-unimportant');
          $badge.text(parseInt($badge.text(), 10) + 1);
        }
      }
    },
    onScroll: function() {
      if(!history_offset || statusIndicator()) return;
      if($(window).scrollTop() !== 0) return;
      statusIndicator('show', 'Loading previous conversations...');
      $.get($.url_for('v1', methods.activeTarget(0), 'history', history_offset), function(data) {
        var $data = $(data);
        if($data.children('li').length) {
          var height_before_prepend = $('body').height();
          $(messages_selector).prepend($data.children('li'));
          $(window).scrollTop($('body').height() - height_before_prepend);
          statusIndicator('fadeOut');
          history_offset = $data.attr('data-offset');
        }
        else {
          history_offset = 0;
          statusIndicator('show', 'End of conversation log.');
          setTimeout(function() { statusIndicator('fadeOut'); }, 5000);
        }
      });
    },
    onSubmit: function() {
      methods.sendData($(input_selector).val());
      $(input_selector).val(''); // TODO: Do not clear the input field until echo is returned?
      return false;
    }
  };

  $.fn.wircChat = function(method) {
    if(!method) {
      methods.init.call(this);
      return this;
    }
    else if(methods[method]) {
      return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
    }
    else {
      $.error('Method ' + method + ' does not exist on jQuery.wircChat');
    }
  };

  $(document).ready(function() {
    if($('#messages').length) $(document).wircChat();
  });
})(jQuery);
