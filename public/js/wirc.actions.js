;(function($) {
  var confirmFirst = function() {
    var $a = $(this);
    var confirm_text = 'Click again to confirm';
    var original_text = $a.text();
    if(original_text == confirm_text) return true;
    $a.text(confirm_text).one('mouseleave', function() { $a.text(original_text); });
    return false;
  };

  var gotoConnection = function() {
    var $select = $(this);
    var cid = $select.find(":selected").attr('value');
    location.href = location.href.replace(/\/settings.*/, '/settings/' + cid);
  };

  var toggleElementWithClick = function() {
    var $a = $(this);
    var selector = $a.attr('data-toggle-element');
    var toggler;

    toggler = function(e) {
      var $target = $(selector);

      if($(e.target).closest($target).length) return true; // prevent hiding when clicking inside forms
      $target.toggle();
      $('a[data-toggle-element]').filter('.active').trigger('toggler_hide');
      $(document).unbind('click', toggler);

      if($target.is(':visible')) {
        $a.addClass('active');
        $(document).one('click', toggler);
      }

      return false;
    };

    $a.click(toggler);
    $a.on('toggler_hide', function() { $a.removeClass('active'); $(selector).hide(); });
    $a.on('toggler_show', function() { $a.addClass('active'); $(selector).show(); });
  };

  $(document).ready(function() {
    $('.settings select[name="cid"]').change(gotoConnection);
    $('a[data-toggle-element]').each(toggleElementWithClick).filter('.active').trigger('toggler_show');
    $('a.confirm').click(confirmFirst);

    $(document).on('completely_ready', function() {
      $('form.focus:first').each(function() {
        $('html, body').scrollTop($(this).offset().top - 50);
      });
    });
  });
})(jQuery);