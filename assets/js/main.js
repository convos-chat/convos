(function() {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  Convos.error = function(err) {
    var h2 = document.querySelector("h2");
    var p = document.querySelector("p.message");
    h2.className = "";
    h2.innerText = "Could not load Convos";
    p.className = "alert";
    p.innerText = err;
  };

  // shift+enter is a global shortkey to jump between input fields and goto anything
  document.addEventListener("keydown", function(e) {
    if (e.shiftKey && e.keyCode == 13) { // shift+enter
      e.preventDefault();
      var el = document.activeElement || document.getElementById("goto_anything");
      if (el.id == "goto_anything" || el.tagName.toLowerCase() == "body") {
        document.querySelector('.convos-dialog-container.active')
          .querySelector('input:not([type="hidden"]), textarea, select').focus();
      }
      else {
        document.getElementById("goto_anything").focus();
      }
    }
  });

  var m;
  if (m = location.href.match(/\b_error=([^&]+)\b/)) return Convos.error(m[1]);
  if (m = location.href.match(/\b_vue=false\b/)) return;

  Convos.api = new openAPI(Convos.apiUrl, function(err) {
    if (err) return Convos.error("Could not load API spec! " + err);

    var data = {mixins: [], user: new Convos.User()};
    Convos.beforeCreate.forEach(function(cb) { cb(data); });
    var mixins = data.mixins;
    delete data.mixins;

    Convos.vm = new Vue({
      el: "body",
      data: data,
      mixins: mixins,
      watch: {
        "settings.expandUrls": function(v, o) {
          localStorage.setItem("expandUrls", v ? "true" : "false");
        },
        "settings.main": function(v, o) {
          if (DEBUG.watch && v != o) console.log("[loc:main] " + (o || "null") + " => " + (v || "null"));
          localStorage.setItem("main", v);
        },
        "settings.notifications": function(v, o) {
          if (DEBUG.watch && v != o) console.log("[notifications] " + v);
          if (v == "granted") Notification.simple("convosbot", "You have enabled notifications!");
          localStorage.setItem("notifications", v);
        },
        "settings.sortDialogsBy": function(v, o) {
          if (DEBUG.watch && v != o) console.log("[loc:sortDialogsBy] " + (o || "<unset>") + " => " + (v || "<unset>"));
          localStorage.setItem("sortDialogsBy", v);
        },
        "settings.sidebar": function(v, o) {
          if (DEBUG.watch && v != o) console.log("[loc:sidebar] " + (o || "<unset>") + " => " + (v || "<unset>"));
          localStorage.setItem("sidebar", v);
        }
      },
      ready: function() {
        this.user.refresh();
      }
    });
  });
})();
