(function() {
  Vue.config.debug    = Convos.mode == "development";
  Vue.config.devtools = Convos.mode == "development";

  Convos.error = function(err) {
    document.querySelector("#loader .error").innerText = err;
  };

  // shift+enter is a global shortkey to jump between input fields and goto anything
  document.addEventListener("keydown", function(e) {
    if (e.shiftKey && e.keyCode == 13) { // shift+enter
      e.preventDefault();
      var el = document.activeElement || document.getElementById("goto_anything");
      if (el.id == "goto_anything" || el.tagName.toLowerCase() == "body") {
        document.querySelector('.convos-chat > div:not(.convos-main-menu):not(.inactive)')
          .querySelector('input:not([type="hidden"]), textarea, select').focus();
      }
      else {
        document.getElementById("goto_anything").focus();
      }
    }
  });

  Convos.api = new openAPI(Convos.apiUrl, function(err) {
    if (err) return Convos.error("Could not load API spec! " + err);

    var detail = {data: {user: new Convos.User()}, mixins: []};
    document.dispatchEvent(new CustomEvent("beforeConvosStart", {detail: detail}));

    Convos.vm = new Vue({
      el: "body",
      data: detail.data,
      mixins: detail.mixins,
      watch: {
        "settings.expandUrls": function(v, o) {
          localStorage.setItem("expandUrls", v ? "true" : "false");
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
        "settings.sortDialogsBy": function(v, o) {
          if (DEBUG && v != o) console.log("[loc:sortDialogsBy] " + (o || "<unset>") + " => " + (v || "<unset>"));
          localStorage.setItem("sortDialogsBy", v);
        },
        "settings.sidebar": function(v, o) {
          if (DEBUG && v != o) console.log("[loc:sidebar] " + (o || "<unset>") + " => " + (v || "<unset>"));
          localStorage.setItem("sidebar", v);
        }
      },
      ready: function() {
        this.user.refresh(); // Want to refresh dialogs even if WebSocket fails
      }
    });
  });
})();
