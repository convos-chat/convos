;(function($) {

  var confirmFirst = function() {
    var $a = $(this);
    var confirm_text = 'Click again to confirm';
    var original_text = $a.text();
    if(original_text == confirm_text) return true;
    $a.text(confirm_text).one('mouseleave', function() { $a.text(original_text); });
    return false;
  };

  var gotoConnectionSettings = function() {
    var $select = $(this);
    var cid = $select.find(":selected").attr('value');
    location.href = location.href.replace(/\/settings.*/, '/settings/' + cid);
  };

  var toggleElementWithClick = function() {
    var $a = $(this);
    var focus = $a.attr('data-focus');
    var target = $a.attr('data-toggle');

    $a.click(function(e) {
      var $target = $(target);
      var is_active = $a.hasClass('active');

      $('a[data-toggle]').filter('.active').trigger('deactivate');
      if(is_active) return false;

      if(!$a.hasClass('active')) {
        $a.addClass('active');
        $target.show();
        toggleElementWithClick.visible = $target;
        if(focus) $(focus).focus();
      }

      return false;
    });

    $a.on('deactivate', function() { $a.removeClass('active'); $(target).hide(); toggleElementWithClick.visible = false; });
    $a.on('activate', function() { $a.removeClass('active'); $a.click(); });
  };

  $(document).ready(function() {
    var $togglers = $('a[data-toggle]').each(toggleElementWithClick);
    var $focus = $togglers.filter('.active').trigger('activate').filter('.focus');
    var $login_button = $('a[data-toggle="div.login"]');

    $(document).click(function(e) {
      var $target = toggleElementWithClick.visible;
      if(!$target) return true;
      if($target.hasClass('ignore-document-close')) return true;
      if($(e.target).closest($target).length) return true; // prevent hiding when clicking inside forms
      $('a[data-toggle]').filter('.active').trigger('deactivate');
      return false;
    });

    $('.settings select[name="cid"]').change(gotoConnectionSettings);
    $('a.confirm').click(confirmFirst);
    
     $('a.notification-list').click(function() {
       $.post($.url_for('clear_notifications'));
       $('a.notification-list').children('b').text(0);
     });

    if($login_button.length) {
      $('body').bind('keydown', 'shift+return', function(e) {
        e.preventDefault();
        $login_button.click();
      });
    }

    $(document).on('completely_ready', function() {
      if(!$focus.offset()) return;
      $('html, body').scrollTop($focus.offset().top - 20);
    });
  });
})(jQuery);