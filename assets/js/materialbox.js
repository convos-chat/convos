(function($) {
  var $materialbox, margin = 30;

  var close = function(e) {
    $materialbox.removeClass("active");
  };

  var materialbox = function() {
    if (!$materialbox) {
      $materialbox = $('<div class="materialbox-overlay"></div>').click(close);
      $("body").append($materialbox);
    }
    return $materialbox;
  }

  var open = function(e) {
    var $origin = $(this);
    var $clone = $origin.clone().removeAttr("class");
    var offset = $origin.offset();
    var maxWidth = window.innerWidth - margin;
    var maxHeight = window.innerHeight - margin;
    var cloneWidth, cloneHeight;

    materialbox().html($clone);
    cloneWidth = $clone.width();
    cloneHeight = $clone.height();

    if (cloneWidth > maxWidth) {
      cloneHeight = cloneHeight * maxWidth / cloneWidth;
      cloneWidth = maxWidth;
    }
    if (cloneHeight > maxHeight) {
      cloneWidth = cloneWidth * maxHeight / cloneHeight;
      cloneHeight = maxHeight;
    }

    $clone.css({
      position: "absolute",
      left: offset.left,
      top: offset.top,
      height: $origin.height(),
      width: $origin.width()
    });

    materialbox().addClass("active");
    setTimeout(function() {
      $clone.css({
        left: Math.floor(maxWidth / 2 - cloneWidth / 2 + margin / 2) + "px",
        top: Math.floor(maxHeight / 2 - cloneHeight / 2 + margin / 2) + "px",
        width: cloneWidth,
        height: cloneHeight
      });
    }, 1);
  };

  $.fn.materialbox = function() {
    return this.off("click", open).on("click", open);
  };
}(jQuery));
