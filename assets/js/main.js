(function($) {
  Router.add(/^chat/,      'chat');
  Router.add(/^login$/,    'user-login');
  Router.add(/^logout$/,   function() { });
  Router.add(/^register$/, 'user-register');
  Router.add(/.?/,         'user-login');

  var loggedIn = false;
  var convosFailedToload = function(err) {
    clearTimeout(convosFailedToload.tid);
    $('.loading-convos h5').html('Oh noes! Convos failed to load :(').attr('class', 'red-text');
    $('.loading-convos p').not('.rendered').html(err || 'Maybe you have a browser from last century?').attr('class', 'red-text');
  };

  window.convos = new Convos.User();
  convosFailedToload.tid = setTimeout(convosFailedToload, 5000);

  Router.on('afterDispatch', function() {
    $('select').material_select();
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
  });

  Router.start();

  // email is set after a successful login, either as a result from load()
  // below or when submitting a form from user-register.tag or user-login.tag.
  convos.on('email', function(email) {
    if (loggedIn || !email) return;
    $('body .loading-convos').remove();
    Router.route(Router.url().path.match(/^(login|register|)$/) ? 'chat' : false);
    loggedIn = true;
  });

  convos.load(function(err) {
    var path = Router.url().path;
    $('.loading-convos').remove();
    if (err) Router.route(path == 'register' ? path : 'login', {errors: err});
  });
})(jQuery);
