;(function($) {

  var gotoConnection = function() {
    var $select = $(this);
    var cid = $select.find(":selected").attr('value');
    location.href = location.href.replace(/\/settings.*/, '/settings/' + cid);
  };

  var toggleElementWithClick = function() {
    var $a = $(this);
    var $target = $( $a.attr('data-toggle-element') );
    var toggler;

    toggler = function(e) {
      console.log($a);
      if($(e.target).closest($target).length) {
        return true; // prevent hiding when clicking inside forms
      }

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
    $a.on('toggler_hide', function() { $a.removeClass('active'); $target.hide(); });
    $a.on('toggler_show', function() { $a.addClass('active'); $target.show(); });
  };

  var whenDocumentHasBeenDrawed = function() {
    $('form.focus:first').each(function() {
      $('html, body').scrollTop($(this).offset().top - 50);
    });
  };

  $(document).ready(function() {
    $('.settings select[name="cid"]').change(gotoConnection);
    $('a[data-toggle-element]').each(toggleElementWithClick).filter('.active').trigger('toggler_show');

    setTimeout(whenDocumentHasBeenDrawed, 100);
  });
})(jQuery);