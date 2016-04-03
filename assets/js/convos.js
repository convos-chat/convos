(function() {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  document.querySelectorAll('script[type="vue/component"]').$forEach(function(el) {
    var template = el.previousElementSibling;
    var name     = template.className.replace(/^vue-/, "");
    var module   = eval("(function(module){" + el.innerHTML + ";return module})({})");
    module.exports.template = '<div class="' + name + '">' + template.innerHTML + "</div>";
    Vue.component(name, module.exports);
  });

  Convos.error = function(err) {
    document.querySelector("#loader .error").innerText = err;
  };

  Convos.api = new swaggerClient();
  Convos.api.ws(new ReconnectingWebSocket(Convos.wsUrl));
  Convos.api.load(Convos.apiUrl, function(err) {
    if (err) return Convos.error("Could not load API spec! " + err);

    Convos.vm = new Vue({
      el:   "body",
      data: {
        connections: [],
        dialogs:     [],
        currentPage: "",
        settings:    Convos.settings,
        user:        new Convos.User({})
      },
      ready: function() {
        var self = this;

        this.user.on("updated", function() {
          if (!this.email && self.currentPage != "user-register")
            self.currentPage = "user-login";
          if (this.email) {
            self.currentPage = "convos-chat";
          }
        });

        this.user.load(function(err) {
          document.getElementById("loader").$remove();
          self.$el.style.display = "block";
          self.currentPage = err ? "user-login": "convos-chat"
        });
      }
    });
  });
})();
