// Global mixin for rendering materialize components
(function() {
  var $hint   = '<div class="material-hint"><span></span></div>';
  var spacing = 4;
  var transitionDelay;

  var showHint = function() {
    var $el    = $(this);
    var text   = $el.attr("data-hint");
    var offset = $el.offset();
    var css    = {};

    if (text.match(/^\s*$/)) return; // do not want to show empty tooltip
    $hint.text(text).addClass("active");

    css.right = "unset";
    css.left  = offset.left - ($hint.outerWidth() - $el.outerWidth()) / 2;
    css.top   = offset.top - $hint.outerHeight() - spacing;

    if (css.left < 0) {
      css.left = spacing;
    } else if (css.left + $hint.outerWidth() + spacing > $(window).width()) {
      css.left  = "unset";
      css.right = spacing;
    }

    if (css.top < spacing) {
      css.top = offset.top + $el.outerHeight() + spacing;
    }

    Object.keys(css).forEach(function(k) {
      if (parseInt(css[k]))
        css[k] = css[k] + "px";
    });

    $hint.css(css);
  };

  var hideHint = function() {
    $hint.css("transition-delay", "100ms").removeClass("active");
    setTimeout(function() {
      $hint.css("transition-delay", transitionDelay + "s");
    }, transitionDelay * 1000);
  };

  Vue.mixin({
    methods: {
      materializeComponent: function() {
        this.$nextTick(function() {
          this.overrideHints();
          Materialize.updateTextFields();
        });
      },
      overrideHints: function() {
        $("[data-hint]", this.$el).each(function() {
          var $el = $(this);
          if (!$el.hasClass("js-hint")) $el.hover(showHint, hideHint).addClass("js-hint");
          if (typeof $hint != "string") return;
          $hint           = $($hint).appendTo("body");
          transitionDelay = $hint.css("transition-delay").replace(/s/, "") || 500;
        });
      }
    },
    created: function() {
      this.materializeComponent();
    }
  });
})();
