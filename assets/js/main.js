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
        "currentPage": function(v, o) {
          try { document.getElementById("loader").$remove() } catch(e) {};
        },
        "settings.main": function(v, o) {
          if (DEBUG && v != o) console.log("[loc:main] " + (o || "null") + " => " + (v || "null"));
          localStorage.setItem("main", v);
        },
        "settings.notifications": function(v, o) {
          if (DEBUG && v != o) console.log("[notifications] " + v);
          if (v == "granted") Notification.simple("convosbot", "You have enabled notifications!");
          localStorage.setItem("notifications", v);
        },
        "settings.sidebar": function(v, o) {
          if (DEBUG && v != o) console.log("[loc:sidebar] " + (o || "null") + " => " + (v || "null"));
          localStorage.setItem("sidebar", v);
        }
      },
      events: {
        login: function(data) {
          var self = this;
          var user = this.user;
          var cache = {};
          if (user.email) return console.log("Already logged in.");
          this.user.email = data.email;
          this.settings.dialogsVisible = false;

          Convos.api.ws().on("close", function() {
            user.connections.forEach(function(c) { c.state = "unreachable"; });
            user.dialogs.forEach(function(d) { d.frozen = "Websocket closed."; });
          });

          Convos.api.ws().on("json", function(data) {
            if (!data.connection_id) return;
            var c = user.getConnection(data.connection_id);
            if (c) return c.emit(data.event, data);
            if (!cache[data.connection_id]) cache[data.connection_id] = [];
            cache[data.connection_id].push(data);
          });

          Convos.api.ws().on("open", function(data) {
            user.getNotifications(function(err) {});
            user.refreshConnections(function(err) {
              if (err) return console.log(err); // TODO
              user.refreshDialogs(function(err) {
                user.makeSureLocationIsCorrect();
                self.currentPage = "convos-chat";
                Object.keys(cache).forEach(function(connection_id) {
                  var msg = cache[connection_id];
                  var c = user.getConnection(connection_id);
                  delete cache[connection_id];
                  if (c) msg.forEach(function(d) { c.emit(d.event, d); });
                });
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
          if (err) return self.currentPage = "convos-login";
          self.$emit("login", xhr.body);
        });
      }
    });
  });
})();
