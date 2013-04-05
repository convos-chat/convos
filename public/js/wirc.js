(function($) {
  var input_selector = '.chat form input[type="text"]';
  var messages_selector = '#messages ul';
  var at_bottom = true;
  var websocket = {};
  var history_offset, conversation_name, $conversation, $connection_list;

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
      methods.onResize();
      notifier.init();

      $('.embed img').live('click', function() { $(this).remove(); });
      $(input_selector).chatInput().parents('form').submit(methods.onSubmit);
      $(window).resize(methods.onResize);

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
          $connection_list.hide();
          $('#navbar').find('a').parent('li').removeClass('open');
          $('body').unbind('click', hide);
      };
      var show = function(e) {
        var $li = $(this).parent('li:first');
        hide.call(this, e);
        $connection_list.css('right', $(window).width() - $li.offset().left - $li.width() - 43).show();
        $li.addClass('open');
        $('body').one('click', hide);
      };

      $('#navbar .brand').click(function(e) {
        methods.sendData('/topic');
        return false;
      });

      $('#navbar .unread-menu').click(function(e) {
        if($(this).parent('li:first').hasClass('open')) return hide.call(this, e);
        $connection_list.find('.channel, .conversation').each(function() {
          if($(this).find('.badge').text() == '0') $(this).hide();
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
      var $input = $('input');

      $(document).bind('keydown', 'shift+return', function() {
        $(input_selector).focus();
      });
      $input.bind('keydown', 'ctrl+up', function(e) {
        e.preventDefault();
        $('#connection_list li.active').prev().find('a').click();
      });
      $input.bind('keydown', 'ctrl+down', function(e) {
        e.preventDefault();
        $('#connection_list li.active').next().find('a').click();
      });
      $input.bind('keydown', 'ctrl+shift+up', function() {
        $('#connection_list li.active').prevAll().each(function(i) {
          if($(this).find('.badge:visible').length) {
            $(this).find('a').click();
            return false;
          }
        });
      });
      $input.bind('keydown', 'ctrl+shift+down', function() {
        $('#connection_list li.active').nextAll().each(function(i) {
          if($(this).find('.badge:visible').length) {
            $(this).find('a').click();
            return false;
          }
        });
      });
    },
    activeTarget: function(escaped) {
      var target = $conversation.attr('id').replace(/^conversation_/, '');
      return escaped ? target.replace(/:/g, '\\:') : target;
    },
    changeConversation: function(e) {
      var $target = e ? $(e.relatedTarget) : false;

      $conversation = $('#messages ul:first');
      $(window).scrollToBottom();
      $(input_selector).chatInput('initAutocomplete', $conversation.attr('data-nicks').replace(/\@/g, '').split(','));
      $('#connection_list li').removeClass('active');
      $('#target_' + methods.activeTarget(1)).addClass('active').find('.badge').text('0').removeClass('badge-important').hide();

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
        $('#connection_list span.badge').each(function() {
          n += parseInt($(this).text(), 10);
        });
        $('#navbar .unread-menu .badge-unimportant').text(n);
        $('#navbar .unread-menu .badge-important').text(0); // TODO: This should be calculated like unimportant
      }
      else {
        var $badge = $('#target_' + target + ' .badge');
        $badge.text(parseInt($badge.text(), 10) + 1).show();
        if(action == 'important') {
          $badge.addClass('badge-important');
          $badge = $('#navbar .unread-menu .badge-important');
          $badge.text(parseInt($badge.text(), 10) + 1);
        }
        else {
          $badge = $('#navbar .unread-menu .badge-unimportant');
          $badge.text(parseInt($badge.text(), 10) + 1);
        }
      }
    },
    onResize: function() {
      var h = $(window).height() - 60;
      $('#connection_list .dropdown-menu').css({ 'max-height': h });
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
