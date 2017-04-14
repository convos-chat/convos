(function() {
  // <a v-link.literal="#foo/bar">...</a>
  Vue.directive("link", {
    bind: function() {
      var vm = this.vm;
      this.el.addEventListener("click", function(e) {
        var m, href = e.currentTarget.getAttribute("href");
        e.preventDefault();
        Convos.settings.mainMenuVisible = false;

        if (m = href.match(/^\#page:(.+)/)) {
          vm.user.currentPage = "convos-" + m[1];
        }
        else if (m = href.match(/^(\#.+)/)) {
          Convos.settings.main = m[1];
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
