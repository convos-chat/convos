(function($) {
  var margin = 30;
  var id     = 0;

  var close = function(e) {
    $(this).removeClass("active");
  };

  var open = function(e) {
    var $origin      = $(this);
    var $materialbox = $('<div class="materialbox-overlay"></div>');
    var $clone       = $origin.clone().removeAttr("class");
    var id           = $origin.attr("data-materialbox-id");
    var offset       = $origin.offset();

    $materialbox.attr("id", id).click(close).append($clone);
    $("body").append($materialbox);

    var maxWidth  = window.innerWidth - margin;
    var maxHeight = window.innerHeight - margin;
    var width     = $clone.width();
    var height    = $clone.height();

    if (width > maxWidth) {
      height = height * maxWidth / width;
      width  = windowWidth;
    }
    if (height > maxHeight) {
      width  = width * maxHeight / height;
      height = maxHeight;
    }

    $clone.css({
      position: "absolute",
      left:     offset.left,
      top:      offset.top,
      height:   $origin.height(),
      width:    $origin.width()
    });

    setTimeout(function() {
      $materialbox.addClass("active");
      $clone.css({
        left:   Math.floor(maxWidth / 2 - width / 2 + margin / 2) + "px",
        top:    Math.floor(maxHeight / 2 - height / 2 + margin / 2) + "px",
        width:  width,
        height: height
      });
    }, 1);
  };

  $.fn.materialbox = function() {
    return this.each(function() {
      var $origin = $(this);
      if ($origin.attr("data-materialbox-id")) return;
      $origin.attr("data-materialbox-id", "materialbox_overlay_" + (++id));
      $origin.click(open);
    });
  };
}(jQuery));
