(function() {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  document.querySelectorAll('script[type="vue/component"]').$forEach(function(el) {
    var template = el.previousElementSibling;
    var name     = template.className.replace(/^vue-/, "");
    var module   = eval("// " + name + "\n(function(module){" + el.innerHTML + ";return module})({})");
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
        convosDialog: new Convos.Dialog({is_private: true, name: "convosbot"}),
        currentPage:  "",
        settings:     Convos.settings,
        user:         {
          connections:  [],
          dialogs:      [],
          email:        ""
        }
      },
      events: {
        login: function(data) {
          var self = this;
          if (this.user.email) return console.log("Already logged in.");
          this.user.email  = data.email;
          this.currentPage = "convos-chat";

          Convos.api.ws().on("json", function(data) {
            if (!data.cid) return;
            var target = self.findDialog(data.tid) || self.findConnection(data.cid);
            console.log(data.event, target ? target.id : data, data.type);
            if (target) target.emit(data.event, data);
          });

          Convos.api.ws().open(function() {
            self.refreshConnections(function(err) {
              if (err) return console.log(err); // TODO
              this.refreshDialogs(function(err) {
                if (err) return console.log(err); // TODO
              });
            });
          });
        },
        logout: function() {
          Convos.api.ws().close();
          this.connections = [];
          this.currentPage = "user-login";
          this.dialogs     = [];
          this.user.email  = "";
        }
      },
      methods: {
        findConnection: function(id) {
          return this.user.connections.filter(function(c) {
            return c.id == id;
          })[0];
        },
        findDialog: function(id) {
          return this.user.dialogs.filter(function(d) {
            return d.id == id;
          })[0];
        },
        refreshConnections: function(cb) {
          var self = this;
          Convos.api.listConnections({}, function(err, xhr) {
            if (err) return cb.call(self, err);
            self.user.connections = [];
            xhr.body.connections.forEach(function(c) {
              c.user = self.user;
              self.user.connections.push(new Convos.Connection(c));
            });
            cb.call(self, err);
          });
        },
        refreshDialogs: function(cb) {
          var self         = this;
          Convos.api.listDialogs({}, function(err, xhr) {
            if (err) return cb.call(self, err);
            self.user.dialogs = [];
            xhr.body.dialogs.forEach(function(d) {
              d.connection = self.findConnection(d.connection_id);
              d.user       = self.user;
              self.user.dialogs.push(new Convos.Dialog(d));
            });
            self.user.dialogs.push(self.convosDialog);
          });
          cb.call(self, err);
        }
      },
      ready: function() {
        var self = this;

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
