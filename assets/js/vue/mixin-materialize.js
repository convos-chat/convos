// Global mixin for rendering materialize components
(function() {
  Vue.mixin({
    methods: {
      materializeComponent: function() {
        this.$nextTick(function() {
          Materialize.updateTextFields();
        });
      }
    },
    created: function() {
      this.materializeComponent();
    }
  });
})();
