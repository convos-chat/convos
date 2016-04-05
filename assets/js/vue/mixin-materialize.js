// Global mixin for rendering materialize components
Vue.mixin({
  methods: {
    materializeComponent: function() {
      $(".material-tooltip").hide();
      $(".tooltipped", this.$el).each(function() {
        var $t = $(this);
        if ($t.attr("data-tooltip")) return;
        $t.attr("data-tooltip", $t.attr("title") || $t.attr("placeholder")).removeAttr("title");
      }).filter("[data-tooltip]").tooltip();
      this.$nextTick(function() {
        Materialize.updateTextFields();
      });
    }
  },
  created: function() {
    this.materializeComponent();
  }
});
