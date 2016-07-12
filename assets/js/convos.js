(function() {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  document.querySelectorAll('script[type="vue/component"]').$forEach(function(el) {
    var template = el.previousElementSibling;
    var name     = template.className.replace(/^vue-/, "");
    var module   = eval("// " + name + "\n(function(module){" + el.innerHTML + ";return module})({})");
    module.exports.template = '<div class="' + name + '">' + template.innerHTML + "</div>";
    Vue.component(name, module.exports);
    el.$remove();
    template.$remove();
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
        currentPage:        "",
        embedViewerElement: null,
        settings:           Convos.settings,
        user:               new Convos.User()
      },
      events: {
        login: function(data) {
          var self = this;
          if (this.user.email) return console.log("Already logged in.");
          this.user.email  = data.email;
          this.currentPage = "convos-chat";

          Convos.api.ws().on("close", function() {
            self.user.connections.forEach(function(c) {
              c.state = "unreachable";
            });
            self.user.dialogs.forEach(function(d) {
              if (d.connection)
                d.frozen = "Websocket closed.";
            });
          });

          Convos.api.ws().on("json", function(data) {
            if (!data.connection_id) return;
            var target = self.user.getDialog(data.dialog_id) || self.user.getConnection(data.connection_id);
            // console.log(data.event, target ? target.id : data, data);
            if (target) target.emit(data.event, data);
          });

          Convos.api.ws().on("open", function(data) {
            self.user.refreshConnections(function(err) {
              if (err) return console.log(err); // TODO
              self.user.refreshDialogs(function(err) {
                if (err) return console.log(err); // TODO
              });
            });
          });

          Convos.api.ws().open();
        },
        logout: function() {
          Convos.api.ws().close();
          this.currentPage      = "user-login";
          this.user.connections = [];
          this.user.dialogs     = [];
          this.user.email       = "";
        }
      },
      ready: function() {
        var self = this;

        window.onhashchange = function() { self.$broadcast("locationchange", self.parseLocation()); }

        Convos.api.getUser({}, function(err, xhr) {
          if (!err) self.$emit("login", xhr.body);
          document.getElementById("loader").$remove();
          self.$el.style.display = "block";
          self.currentPage       = err ? "user-login" : "convos-chat";
        });
      }
    });
  });
})();
