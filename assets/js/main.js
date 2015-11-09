(function($) {
  Convos.api = new swaggerClient();
  Convos.ws = new ReconnectingWebSocket(Convos.wsUrl);
  Convos.user = new Convos.User({ws: Convos.ws}); // Convos.user is only for debug purposes and must not be accessed by riot tags
  Convos.api.ws(Convos.ws);
  Convos.api.load(Convos.apiUrl, function(err) {
    Convos.user.load(function(err) {
      if (err && err[0].path == '/') err = [];
      riot.mount(document.getElementById('app'), 'app', {errors: err || [], user: this});
      clearTimeout(Convos.loadTid); // Set in Convos.pm app.html.ep
    });
  });
})(jQuery);
