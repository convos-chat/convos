// Global mixin for rendering materialize components
(function() {
  var $tooltip = '<div class="material-tooltip"><span></span></div>';
  var spacing  = 4;

  var showTooltip = function() {
    if (typeof $tooltip == "string") {
      $tooltip                 = $($tooltip).appendTo("body");
      $tooltip.transitionDelay = $tooltip.css("transition-delay").replace(/s/, "");
    }

    var $el    = $(this);
    var offset = $el.offset();
    var css    = {};

    $tooltip.text($el.attr("data-hint")).addClass("active");

    css.right = "auto";
    css.left  = offset.left - ($tooltip.outerWidth() - $el.outerWidth()) / 2;
    css.top   = offset.top - $tooltip.outerHeight() - spacing;

    if (css.left < 0) {
      css.left = spacing;
    } else if (css.left + $tooltip.outerWidth() + spacing > $(window).width()) {
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

    $tooltip.css(css);
  };

  var hideToolTip = function() {
    $tooltip.css("transition-delay", "100ms").removeClass("active");
    setTimeout(function() {
      $tooltip.css("transition-delay", $tooltip.transitionDelay + "s");
    }, $tooltip.transitionDelay * 1000);
  };

  Vue.mixin({
    methods: {
      materializeComponent: function() {
        this.$nextTick(function() {
          this.overrideTooltips();
          Materialize.updateTextFields();
        });
      },
      overrideTooltips: function() {
        $("[data-hint]", this.$el).each(function() {
          var $el = $(this);
          if (!$el.hasClass("tooltipped")) $el.hover(showTooltip, hideToolTip).addClass("tooltipped");
        });
      }
    },
    created: function() {
      this.materializeComponent();
    }
  });
})();
