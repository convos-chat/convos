;(function($) {

  var toggleConversationList = function(e) {
    $('.conversation-list').toggle();
    $('.conversation-list-button').toggleClass('active');
    $(document).unbind('click', toggleConversationList);

    if($('.conversation-list').is(':visible'))
      $(document).one('click', toggleConversationList);

    return $(e.target).closest('.conversation-list, .settings-button').length ? true : false;
  };

  $(document).ready(function() {
    $('nav .conversation-list-button').click(toggleConversationList);
  });
})(jQuery);