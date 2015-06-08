(function($) {
  Router.add(/^chat/,      'chat');
  Router.add(/^register$/, 'user-register');
  Router.add(/^login$/,    'user-login');
  Router.add(/.?/,         'user-login');

  var convos = Object.create(Convos.User);
  var convosFailedToload = function(err) {
    clearTimeout(convosFailedToload.tid);
    $('.loading-convos h5').html('Oh noes! Convos failed to load :(').attr('class', 'red-text');
    $('.loading-convos p').not('.rendered').html(err || 'Maybe you have a browser from last century?').attr('class', 'red-text');
  };

  convosFailedToload.tid = setTimeout(convosFailedToload, 5000);
  Router.start(convos.render.bind(convos));

  convos.load(function(err) {
    if (err == 401) {
      $('.loading-convos').remove();
      Router.route('login');
    }
    else if (err) {
      convosFailedToload('Could not get user data. (' + err + ')');
    }
    else {
      $('body .loading-convos').remove();
      Router.route(Router.url().path.match(/^(login|register)$/) ? 'chat' : false);
    }
  });

  window.convos = convos;
})(jQuery);
