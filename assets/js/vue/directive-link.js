(function() {
  // <a v-link.literal="#foo/bar">...</a>
  Vue.directive("link", {
    bind: function() {
      var vm = this.vm;
      this.el.addEventListener("click", function(e) {
        e.preventDefault();
        Convos.settings.dialogsVisible = false;
        Convos.settings.main = e.currentTarget.href.replace(/.*?#/, "#");
      });
    },
    update: function(v) {
      this.el.href = v;
    }
  });
})();
