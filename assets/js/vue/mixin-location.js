(function() {
  Vue.mixin({
    methods: {
      parseLocation: function(path) {
        if (!arguments.length) path = location.hash.split("?");
        var params = (path[1] || "").split("&");
        var fragment = (path[0] || "").replace(/^\#/, "").split("/");

        if (!fragment[0].length) fragment.shift();
        fragment.params = {};
        params.forEach(function(p) {
          p = p.split("=");
          fragment.params[p[0]] = decodeURIComponent(p[1]);
        })

        return fragment;
      },
      replaceLocation: function(loc) {
        history.replaceState({}, "", [location.href.split("#")[0], loc].join("#"));
      },
      toggleLocation: function(next, def) {
        var current = this.parseLocation();
        next = this.parseLocation(Array.isArray(next) ? next : next.split("?"));
        location.hash = JSON.stringify(current) == JSON.stringify(next) ? def : next;
      }
    },
    ready: function() {
      this.$emit("locationchange", this.parseLocation());
    }
  });
})();
