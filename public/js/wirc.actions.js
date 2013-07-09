;(function($) {

  var toggleConversationList = function() {
    $('div.conversation-list').toggle();
    $('a.conversation-list-button').toggleClass('active');
    $(document).unbind('click', toggleConversationList);

    if($('div.conversation-list').is(':visible'))
      $(document).one('click', toggleConversationList);

    return false;
  };

  $(document).ready(function() {
    $('nav .conversation-list-button').click(toggleConversationList);
  });
})(jQuery);