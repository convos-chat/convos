(function() {
  // localStorage items are maintained in root Vue object, in main.js
  // TODO: Should come up with better variable names than "main" and "sidebar"
  Convos.settings.main = localStorage.getItem("main") || "";
  Convos.settings.sidebar = localStorage.getItem("sidebar") || "";

  Vue.mixin({
    data: function() {
      return {settings: Convos.settings};
    },
    methods: {
      activeClass: function(href) {
        if (href.currentTarget) href = e.currentTarget.href.replace(/.*?#/, "");
        return {active: Convos.settings.main == href || Convos.settings.sidebar == href};
      },
      insertIntoInput: function(e) {
        var dialog = this.user.getActiveDialog();
        if (dialog) dialog.emit("insertIntoInput", e.currentTarget.href.replace(/.*?#/, ""));
      }
    }
  });

  // <a v-link.literal="#foo/bar">...</a>
  Vue.directive("link", {
    bind: function() {
      var vm = this.vm;
      this.el.addEventListener("click", function(e) {
        e.preventDefault();
        Convos.settings.main = e.currentTarget.href.replace(/.*?#/, "#");
        if (DEBUG) console.log('[loc:main] ' + Convos.settings.main);
      });
    },
    update: function(v) {
      this.el.href = v;
    }
  });

  // <a v-sidebar.literal="#notifications">...</a>
  Vue.directive("sidebar", {
    bind: function() {
      var vm = this.vm;
      this.el.addEventListener("click", function(e) {
        var href = e.currentTarget.href.replace(/.*?#/, "");
        e.preventDefault();
        Convos.settings.sidebar = Convos.settings.sidebar == href ? "" : href;
        if (DEBUG) console.log('[loc:sidebar] ' + (Convos.settings.sidebar || "null"));
      });
    },
    update: function(v) {
      this.el.href = v;
    }
  });
})();
