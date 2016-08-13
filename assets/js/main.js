(function() {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  Convos.error = function(err) {
    document.querySelector("#loader .error").innerText = err;
  };

  Convos.api = new swaggerClient();
  Convos.api.ws(new ReconnectingWebSocket(Convos.wsUrl));
  Convos.api.load(Convos.apiUrl, function(err) {
    if (err) return Convos.error("Could not load API spec! " + err);

    Convos.vm = new Vue({
      el: "body",
      data: {currentPage: "", user: new Convos.User()},
      watch: {
        'settings.main': function(v, o) { localStorage.setItem("main", v); },
        'settings.sidebar': function(v, o) { localStorage.setItem("sidebar", v); }
      },
      events: {
        login: function(data) {
          var self = this;
          if (this.user.email) return console.log("Already logged in.");
          this.user.email = data.email;
          this.currentPage = "convos-chat";
          this.settings.dialogsVisible = false;

          Convos.api.ws().on("close", function() {
            self.user.connections.forEach(function(c) { c.state = "unreachable"; });
            self.user.dialogs.forEach(function(d) { d.frozen = "Websocket closed."; });
          });

          Convos.api.ws().on("json", function(data) {
            if (!data.connection_id) return;
            var target = self.user.getConnection(data.connection_id);
            if (target) return target.emit(data.event, data);
            console.log('json event without connection_id', data);
          });

          Convos.api.ws().on("open", function(data) {
            self.user.getNotifications(function(err) {});
            self.user.refreshConnections(function(err) {
              if (err) return console.log(err); // TODO
              self.user.refreshDialogs(function(err) {
                try { document.getElementById("loader").$remove() } catch(e) {};
                if (!self.settings.main && self.user.dialogs.length)
                  self.settings.main = self.user.dialogs[0].href();
                self.currentPage = "convos-chat";
              });
            });
          });

          Convos.api.ws().open();
        },
        logout: function() {
          Convos.api.ws().close();
          this.currentPage      = "convos-login";
          this.user.connections = [];
          this.user.dialogs     = [];
          this.user.email       = "";
        }
      },
      ready: function() {
        var self = this;

        Convos.api.getUser({}, function(err, xhr) {
          if (!err) self.$emit("login", xhr.body);
        });
      }
    });
  });
})();
