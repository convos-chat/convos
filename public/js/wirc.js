(function($) {
  var input_selector = '.chat form input[type="text"]';
  var messages_selector = '.messages ul';
  var websocket, history_index, $conversation, $conversation_list, $history_indicator;

  var methods = {
    init: function() {
      $conversation_list = $('.conversation-list');

      websocket = new ReconnectingWebSocket($.url_for('socket').replace(/^http/, 'ws'));
      websocket.onmessage = methods.receiveData;

      methods.changeChannel();
      methods.initPjax();
      methods.initShortcuts();
      methods.onResize();
      notifier.init();

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
      $(document).on('pjax:send', function(event) {
        window.the_machine_is_scrolling = true;
        $(event.relatedTarget).parent('li:first').addClass('loading');
        $conversation_list.fadeTo('fast', 0.5);
      });
      $(document).on('pjax:complete', function(event) {
        $(event.relatedTarget).parent('li:first').removeClass('loading');
      });
      $(document).on('pjax:timeout', function(event) {
        event.preventDefault(); // Prevent default timeout redirection behavior
      });
      $('#conversation').on('pjax:end', function(e) {
        methods.changeChannel();
        setTimeout(function() { window.the_machine_is_scrolling = false; }, 100);
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
      var target = $conversation_list.attr('id').replace(/^conversation_/, '');
      return escaped ? target.replace(/:/g, '\\:') : target;
    },
    changeChannel: function() {
      history_index = 1;
      $conversation_list = $('#conversation > ul');
      log('changeChannel', methods.activeTarget());
      $(window).scrollToBottom();
      $(input_selector).chatInput('initAutocomplete', $conversation_list.attr('data-nicks').replace(/\@/g, '').split(','));
      $('.server li').removeClass('active').find('.badge').text('0').removeClass('badge-important').hide();
      $('#target_' + methods.activeTarget(1)).addClass('active');
    },
    printMessage: function(target) {
      if(target === 'any') target = methods.activeTarget(1); // special server messages
      if($('#conversation_' + target).length) {
        var at_bottom = $(window).atBottom(); // need to calculate at_bottom before appending a new element
        $(messages_selector).append(this);
        if($data.hasClass('nick-joined')) {
          txt = $data.children('span').eq(1).text();
          $(input_selector).chatInput('addAutocomplete', [txt.replace(/.*(\S+)$/, '$1')]);
        }
        else if($data.hasClass('nick-parted')) {
          txt = $data.children('span').eq(1).text();
          $(input_selector).chatInput('removeAutocomplete', [txt.replace(/.*(\S+)$/, '')]);
        }
        if(at_bottom) $(window).scrollToBottom();
      }
      else {
        var $badge = $('#target_' + target + ' .badge');
        $badge.text(parseInt($badge.text(), 10) + 1).show();
        if(this.hasClass('highlight')) $badge.addClass('badge-important');
      }
    },
    receiveData: function(e) {
      log('[websocket] >', e.data);
      var $data = $(e.data);
      var target = $data.attr('data-target').replace(/:/g, '\\:');
      var $target = $('#target_' + target);
      var txt;

      // notification handling
      if($data.hasClass('highlight')) {
        if($target.hasClass('conversation')) {
          notifier.popup('New message from ' + $target.attr('title'), $data.find('.content').text(), '');
          notifier.title('New message from ' + $target.attr('title'));
        }
        else {
          notifier.popup('New mention by ' + $data.find('.prefix').text() + ' in ' + $data.find('.content').text(), $data.find('.content').text(), '');
          notifier.title('New mention by ' + $data.find('.prefix').text() + ' in ' + $target.attr('title'));
        }
      }

      // action handling
      if($data.hasClass('add-conversation') || $data.hasClass('remove-conversation')) {
        var p = $data.hasClass('add-conversation') ? $data.attr('data-target') : $data.attr('data-target').replace(/:.*/, '');
        $conversation_list.fadeTo('fast', 0.5);
        return $.get($.url_for('v1', p, 'connection-list'), function(data) {
          var $data = $(data);
          var target = $data.attr('id').replace(/:/g, '\\:');
          $('#' + target).replaceWith($data);
          $('#' + target).find('li.active > a').click();
        });
      }
      else if($data.hasClass('nick-change')) {
        txt = $data.children('span').eq(1).text();
        $(input_selector)
          .chatInput('removeAutocomplete', [txt.replace(/\s.*/, '')], function() { $data.attr('data-target', 'any'); })
          .chatInput('addAutocomplete', [txt.replace(/.*"(.*)"/, '$1')]);
      }

      methods.printMessage.call($data, target);
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
      if(window.the_machine_is_scrolling) return;
      if($history_indicator || $(window).scrollTop() !== 0) return;
      var height_before_load = $('body').height();
      $history_indicator = $('<div class="alert alert-info">Loading previous conversations...</div>');
      $(messages_selector).before($history_indicator);
      log('Load previous conversatins', history_index + 1);
      $.get($.url_for('v1', methods.activeTarget(1), 'history', (++history_index)), function(data) {
        if($(data).find('*').length) {
          $(messages_selector).prepend(data);
          $history_indicator.remove();
          $history_indicator = false;
          $(window).scrollTop($('body').height() - height_before_load);
        }
        else {
          window.the_machine_is_scrolling = true;
          $history_indicator.removeClass('alert-info').text('End of conversation log.');
          setTimeout(function() { $history_indicator.fadeOut('slow'); }, 2000);
        }
      });
    },
    onSubmit: function() {
      var $data = $('<div data-target="' + methods.activeTarget() + '">' + $(input_selector).val() + '</div>').wrap('<div>').parent();
      log('[websocket] <', $data.html());
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
