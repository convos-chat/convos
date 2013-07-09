;(function($) {

  var gotoConnection = function() {
    var $select = $(this);
    var cid = $select.find(":selected").attr('value');
    location.href = location.href.replace(/\/settings.*/, '/settings/' + cid);
  };

  var toggleConversationList = function(e) {
    $('.conversation-list').toggle();
    $('.conversation-list-button').toggleClass('active');
    $(document).unbind('click', toggleConversationList);

    if($('.conversation-list').is(':visible'))
      $(document).one('click', toggleConversationList);

    return $(e.target).closest('.conversation-list, .settings-button').length ? true : false;
  };

  $(document).ready(function() {
    $('.settings select[name="cid"]').change(gotoConnection);

    if($('.conversation-list').length)
      $('nav .conversation-list-button').click(toggleConversationList);
  });
})(jQuery);