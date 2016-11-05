(function() {
  // <a v-link.literal="#foo/bar">...</a>
  Vue.directive("link", {
    bind: function() {
      var vm = this.vm;
      this.el.addEventListener("click", function(e) {
        var href = e.currentTarget.getAttribute("href");
        e.preventDefault();
        Convos.settings.mainMenuVisible = false;

        if (href.match(/^\#/)) {
          Convos.settings.main = href.replace(/.*?#/, "#");
        }
        else {
          window.location = Convos.indexUrl.replace(/\/+$/, '') + href;
        }
      });
    },
    update: function(v) {
      this.el.href = v;
    }
  });
})();
