(function($) {
  var input_selector = '.chat form input[type="text"]';
  var messages_selector = '.messages ul';

  var do_not_load_history = false;
  var history_index = 1;
  var nick = {};
  var cid, target, websocket, $conversation_list, $history_indicator;

  var methods = {
    init: function() {
      $conversation_list = $('.conversation-list');

      methods.changeChannel();
      methods.initPjax();
      methods.initShortcuts();
      methods.initWebSocket();
      methods.onResize();
      notifier.init();

      $('.server').each(function(i) {
        nick[$(this).attr('data-cid')] = $(this).attr('data-nick');
      });

      $('.embed img').live('click', function() { $(this).remove(); });
      $('a.show-hide').fastclick(function() { $conversation_list.toggleClass('hidden open'); return false; });
      $(input_selector).chatInput().parents('form').submit(methods.onSubmit);
      $(window).resize(methods.onResize);

      setTimeout(function() {
        $(window).scrollToBottom().on('scroll', methods.onScroll);
      }, 300);

      log('Wirc.Chat.init() success');
      return this;
    },
    initPjax: function() {
      $(document).on('pjax:send', function() {
        do_not_load_history = true;
        $(input_selector).addClass('loading').prop('disabled', true);
      });
      $(document).on('pjax:complete', function() {
        $(input_selector).removeClass('loading').prop('disabled', false).focus();
      });
      $(document).on('pjax:timeout', function(event) {
        event.preventDefault(); // Prevent default timeout redirection behavior
      });
      $('#conversation').on('pjax:end', function(e) {
        methods.changeChannel();
        setTimeout(function() { do_not_load_history = false; }, 100);
      });
      $(document).pjax('.server a', '#conversation');
    },
    initShortcuts: function() {
      var $input = $('input');

      $(document).bind('keydown', 'shift+return', function() {
        $(input_selector).focus();
      });
      $input.bind('keydown', 'ctrl+up', function(e) {
        e.preventDefault();
        $('.conversation-list li.active').prev().find('a').click();
      });
      $input.bind('keydown', 'ctrl+down', function(e) {
        e.preventDefault();
        $('.conversation-list li.active').next().find('a').click();
      });
      $input.bind('keydown', 'ctrl+shift+up', function() {
        $('.conversation-list li.active').prevAll().each(function(i) {
          if($(this).find('.badge:visible').length) {
            $(this).find('a').click();
            return false;
          }
        });
      });
      $input.bind('keydown', 'ctrl+shift+down', function() {
        $('.conversation-list li.active').nextAll().each(function(i) {
          if($(this).find('.badge:visible').length) {
            $(this).find('a').click();
            return false;
          }
        });
      });
    },
    initWebSocket: function() {
      websocket = new ReconnectingWebSocket($.url_for('socket').replace(/^http/, 'ws'));
      websocket.onmessage = methods.receiveData;
    },
    changeChannel: function() {
      var $chat_messages = $('#chat-messages');
      cid = $chat_messages.attr('data-cid');
      target = $chat_messages.attr('data-target');
      $.each($chat_messages.attr('data-nicks').split(','), function(i, v) {
        if(v == nick) return; // TODO: This does not work since nick is an object
        $(input_selector).chatInput('autoCompleteNicks', { new_nick: v.replace(/^\@/, '') });
      });
      $('.server li').removeClass('active');
      var $target = $('#' + methods.makeTargetId(cid, target));
      $target.addClass('active');
      $target.find('.badge').text('0').removeClass('badge-important').hide();
      $(window).scrollToBottom();
    },
    makeTargetId: function(cid, target) {
      return 'target_' + (target ? cid + '_' + target.replace(/\W/g, '') : cid);
    },
    modifyChannelList: function() {
      var $channel = $('#' + this.attr('id'));

      if(this.hasClass('parted')) {
        $channel.remove();
        if($channel.hasClass('active')) {
          $('#connection_list_' + this.data('cid') + ' .channel:first a').click();
        }
        return;
      }
      if($channel.length) {
        return $channel.find('a').click();
      }

      this.insertAfter('#connection_list_' + this.data('cid') + ' .channel:last');
      this.find('a').click();
    },
    modifyConversationlist: function() {
      var $conversation = $('#' + this.attr('id'));

      if(this.hasClass('closed')) {
        return $conversation.remove();
      }
      if(!$conversation.length) {
        this.appendTo('#connection_list_' + this.data('cid'));
      }
    },
    printMessage: function() {
      if($('#' + this.data('target')).hasClass('active') || ! this.data('target')) {
        var $messages = $(messages_selector);
        var at_bottom = $(window).atBottom(); // need to calculate at_bottom before appending a new element

        $messages.append(this);

        if(at_bottom) {
          do_not_load_history = true;
          $(window).scrollToBottom();
          do_not_load_history = false;
        }
      } else {
        var $badge = $('#' + this.data('target') + ' .badge');
        $badge.text(parseInt($badge.text(), 10) + 1).show();
        if(this.hasClass('highlight')) $badge.addClass('badge-important');
      }
    },
    receiveData: function(e) {
      log('[websocket] >', e.data.length);
      var $data = $(e.data);

      // notification handling
      if($data.hasClass('highlight')) {
        if($('#' + $data.data('target')).hasClass('conversation')) {
          notifier.popup('New message from ' + $('#' + $data.data('target')).attr('title'), $data.find('.content').text());
          notifier.title('New message from ' + $('#' + $data.data('target')).attr('title'));
        }
        else {
          notifier.popup('', 'New mention by ' + $data.find('.prefix').text() + ' in ' + $data.find('.content').text(), $data.find('.content').text());
          notifier.title('New mention by ' + $data.find('.prefix').text() + ' in ' + $data.data('target'));
        }
      }

      // action handling
      if($data.hasClass('channel')) {
        return methods.modifyChannelList.call($data);
      }
      else if($data.hasClass('conversation')) {
        return methods.modifyConversationlist.call($data);
      }

      $(input_selector).chatInput('autoCompleteNicks', {
        old_nick: $data.data('old_nick'),
        new_nick: $data.data('new_nick')}
      );

      methods.printMessage.call($data);
    },
    sendData: function(data) {
      try {
        var $data = $(data).attr({ 'data-cid': cid, 'data-target': target }).wrap('<div>').parent();
        websocket.send($data.html());
        console.log('[websocket] <', $data.html());
      } catch(e) {
        log('[websocket] !', e);
      }
    },
    onResize: function() {
      if($(window).width() < 767) {
        if(!$conversation_list.hasClass('open')) $conversation_list.addClass('hidden');
      }
      else {
        $conversation_list.removeClass('hidden');
      }
    },
    onScroll: function() {
      if(do_not_load_history) return;
      if($history_indicator || $(window).scrollTop() !== 0) return;
      var height_before_load = $('body').height();
      $history_indicator = $('<div class="alert alert-info">Loading previous conversations...</div>');
      $(messages_selector).before($history_indicator);
      log('Load previous conversatins', history_index + 1);
      $.get($.url_for(cid, target, (++history_index)), function(data) {
        if($(data).find('*').length) {
          $(messages_selector).prepend(data);
          $history_indicator.remove();
          $history_indicator = false;
          $(window).scrollTop($('body').height() - height_before_load);
        }
        else {
          do_not_load_history = true;
          $history_indicator.removeClass('alert-info').text('End of conversation log.');
          setTimeout(function() { $history_indicator.fadeOut('slow'); }, 2000);
        }
      });
    },
    onSubmit: function() {
      methods.sendData('<div>' + $(input_selector).val() + '</div>');
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
    if($('body.chat .messages').length) $(document).wircChat();
  });
})(jQuery);
