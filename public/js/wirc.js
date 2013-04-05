(function($) {
  var input_selector = '.chat form input[type="text"]';
  var messages_selector = '.messages ul';
  var at_bottom = true;
  var websocket, history_index, $conversation, $connection_list;

  var methods = {
    init: function() {
      websocket = new ReconnectingWebSocket($.url_for('socket').replace(/^http/, 'ws'));
      websocket.onmessage = methods.receiveData;

      $connection_list = $('.conversation-list');

      methods.changeChannel();
      methods.initPjax();
      methods.initShortcuts();
      methods.onResize();
      notifier.init();

      $('.embed img').live('click', function() { $(this).remove(); });
      $('a.show-hide').fastclick(function() { $connection_list.toggleClass('hidden open'); return false; });
      $(input_selector).chatInput().parents('form').submit(methods.onSubmit);
      $(window).resize(methods.onResize);

      setTimeout(function() {
        $(window).scrollToBottom().on('scroll', methods.onScroll);
      }, 300);

      log('Wirc.Chat.init() success');
      return this;
    },
    initPjax: function() {
      $(document).on('pjax:send', function(event) {
        $(event.relatedTarget).parent('li:first').addClass('loading');
        statusIndicator('show', 'Loading...');
      });
      $(document).on('pjax:complete', function(event) {
        $(event.relatedTarget).parent('li:first').removeClass('loading');
      });
      $(document).on('pjax:timeout', function(event) {
        event.preventDefault(); // Prevent default timeout redirection behavior
      });
      $('#conversation').on('pjax:end', function(e) {
        statusIndicator('fadeOut');
        methods.changeChannel();
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
    activeTarget: function(escaped) {
      var target = $conversation.attr('id').replace(/^conversation_/, '');
      return escaped ? target.replace(/:/g, '\\:') : target;
    },
    changeChannel: function() {
      history_index = 1;
      $conversation = $('#conversation > ul');
      $(window).scrollToBottom();
      $(input_selector).chatInput('initAutocomplete', $conversation.attr('data-nicks').replace(/\@/g, '').split(','));
      $('.server li').removeClass('active');
      $('#target_' + methods.activeTarget(1)).addClass('active').find('.badge').text('0').removeClass('badge-important').hide();
      log('changeChannel', $conversation.attr('id'));
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
        this.find('img').once('load', function() {
          if(at_bottom) $(window).scrollToBottom();
        });
      }
      else if(this.hasClass('message')) {
        var $badge = $('#target_' + target + ' .badge');
        $badge.text(parseInt($badge.text(), 10) + 1).show();
        if(this.hasClass('highlight')) $badge.addClass('badge-important');
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

      methods.printMessage.call($data, target);
    },
    onResize: function() {
      if(at_bottom) $(window).scrollToBottom();
      if($(window).width() < 767) {
        if(!$connection_list.hasClass('open')) $connection_list.addClass('hidden');
      }
      else {
        $connection_list.removeClass('hidden');
      }
    },
    onScroll: function() {
      at_bottom = $(window).atBottom(); // need to calculate at_bottom before appending a new element
      if(!history_index || statusIndicator()) return;
      if($(window).scrollTop() !== 0) return;
      statusIndicator('show', 'Loading previous conversations...');
      $.get($.url_for('v1', methods.activeTarget(0), 'history', (++history_index)), function(data) {
        if($(data).find('*').length) {
          var height_before_prepend = $('body').height();
          statusIndicator('fadeOut');
          $(messages_selector).prepend(data);
          $(window).scrollTop($('body').height() - height_before_prepend);
        }
        else {
          history_index = 0;
          statusIndicator('show', 'End of conversation log.');
          setTimeout(function() { statusIndicator('fadeOut'); }, 5000);
        }
      });
    },
    onSubmit: function() {
      var $data = $('<div data-target="' + methods.activeTarget() + '">' + $(input_selector).val() + '</div>').wrap('<div>').parent();
      websocket.send($data.html());
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
