(function($) {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  Convos.render         = "loading";
  Convos.api            = new swaggerClient();
  Convos.user           = new Convos.User({});
  Convos.visibleSection = "";

  Convos.tag = function(name) {
    var el = document.querySelector("#vue-" + name);
    return '<div class="' + name + '">' + el.innerHTML + "</div>";
  };

  Convos.user.on("updated", function() {
    if (!this.email && Convos.render != "register")
      Convos.render = "login";
    if (this.email) {
      Convos.render = "chat";
    }
  });

  document.querySelectorAll('script[type="vue/component"]').$forEach(function(el) {
    eval(el.innerHTML);
  });

  Convos = new Vue({
    el:    "convos",
    data:  Convos,
    ready: function() {
      $(this.$el).show();
    }
  });

  // TODO: Handle "err"
  Convos.api.load(Convos.apiUrl, function(err) {
    Convos.user.load(function(err) {
      if (err) Convos.render = "login";
    });
  });
})(jQuery);
