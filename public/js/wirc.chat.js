;(function($) {
  var $input, $messages, $win, chat_ws, current_target, history_offset;

  var getHistory = function() {
    if(!history_offset || $win.scrollTop() !== 0) return;
    $.get($.url_for('v1', current_target, 'history', history_offset), function(data) {
      var $data = $(data);
      if($data.children('li').length === 0) return;
      var height_before_prepend = $('body').height();
      $messages.prepend($data.children('li'));
      $win.scrollTop($('body').height() - height_before_prepend);
      history_offset = $data.attr('data-offset');
    });
    history_offset = 0;
  };

  var receiveMessage = function(e) {
    var $data = $(e.data);
    var target = targetToSelector($data.attr('data-target'));
    var channel = /:23(.+)/.exec(target); // ":23" = "#"
    var at_bottom = $win.data('at_bottom');
    var txt;

    if(reloadConversationList($data, target)) {
      $.get($.url_for('v1/conversation-list'), function(data) {
        $('div.conversation-list').replaceWith(data);
      });
    }
    if($data.hasClass('highlight')) {
      var sender = $data.attr('data-sender');
      var what = channel ? 'mentioned you in #' + channel[1] : 'sent you a message';
      window.notify([sender, what].join(' '), $data.find('.content').text(), '');
    }
    if($data.hasClass('topic')) {
      $('navbar a.current').attr('title', $data.find('span:eq(1)').text());
    }
    if($('#conversation_' + target).length) {
      $messages.append($data.fadeIn('fast'));
    }
    if(at_bottom) {
      $win.scrollToBottom();
      $data.find('img').one('load', function() { $win.scrollToBottom() });
    }

    $input.removeClass('sending');
  };

  var redrawUI = function() {
    if($win.data('at_bottom')) $win.scrollToBottom();
  };

  var reloadConversationList = function($data, target) {
    if($('#conversation_' + target).length) return false;
    if($('#target_' + target).length === 0) return true;
    if($data.hasClass('add-conversation')) return true;
    if($data.hasClass('remove-conversation')) return true;
    if($data.hasClass('important') && $data.hasClass('message')) return true;
    return false;
  }

  var sendMessage = function(message) {
    var $message = $('<div data-target="' + current_target + '"></div>').text(message);
    chat_ws.send($message.prop('outerHTML'));
    $input.addClass('sending');
  };

  var targetToSelector = function(target) {
    if(target === 'any') target = current_target;
    return target.replace(/:/g, '\\:');
  }

  $(document).ready(function() {
    $input = $('footer form input');
    $n_notifications = $('a.conversation-list b');
    $messages = $('.messages ul:first');
    $win = $(window);

    if($messages.length === 0) return; // not on chat page

    chat_ws = $.ws($.url_for('socket').replace(/^http/, 'ws'));
    current_target = $messages.attr('id').replace(/^conversation_/, '');
    history_offset = $messages.attr('data-offset') || 0;

    $('nav a.current').click(function() { sendMessage('/topic'); $(document).click(); return false; });
    $('nav a.help').click(function(e) { sendMessage('/help'); $(document).click(); return false; })
    $input.closest('form').submit(function() { sendMessage($input.val()); $input.val(''); return false; });
    $win.on('scroll', getHistory).on('resize', redrawUI);
    chat_ws.on('message', receiveMessage);

    // TODO: Add shortcut for changing recent conversations
    $('body, input').bind('keydown', 'shift+return', function(e) {
      e.preventDefault();
      $win.scrollToBottom();
      $input.focus();
    });
  });

  $(document).on('completely_ready', function() {
    $win.scrollToBottom();
    $input.focus();
  });

})(jQuery);