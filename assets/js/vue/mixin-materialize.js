// Global mixin for rendering materialize components
Vue.mixin({
  methods: {
    materializeComponent: function() {
      $(".material-tooltip").hide();
      $(".tooltipped[title]", this.$el).each(function() {
        var $t = $(this);
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
