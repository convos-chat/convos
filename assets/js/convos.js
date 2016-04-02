(function($) {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  Convos.render         = "loading";
  Convos.api            = new swaggerClient();
  Convos.user           = new Convos.User({});
  Convos.visibleSection = "";

  Convos.api.ws(new ReconnectingWebSocket(Convos.wsUrl));

  Convos.user.on("updated", function() {
    if (!this.email && Convos.render != "register")
      Convos.render = "login";
    if (this.email) {
      Convos.render = "chat";
    }
  });

  ["convos-app", "convos-chat"].forEach(function(n) {
    document.registerElement(n);
  });

  document.querySelectorAll('script[type="vue/component"]').$forEach(function(el) {
    var template = el.previousElementSibling;
    var name     = template.className.replace(/^vue-/, "");
    var module   = eval("(function(module){" + el.innerHTML + ";return module})({})");
    module.exports.template = '<div class="' + name + '">' + template.innerHTML + "</div>";
    Vue.component(name, module.exports);
  });

  Convos = new Vue({
    el:    "convos-app",
    data:  Convos,
    ready: function() {
      $(this.$el).show();
    }
  });

  // TODO: Handle "err"
  Convos.api.load(Convos.apiUrl, function(err) {
    Convos.user.load(function(err) {
      if (err)
        Convos.render = "login";
    });
  });
})(jQuery);
