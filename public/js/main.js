(function($) {
  Router.add(/^chat/,      'chat');
  Router.add(/^login$/,    'user-login');
  Router.add(/^logout$/,   function() { });
  Router.add(/^register$/, 'user-register');
  Router.add(/.?/,         'user-login');

  jQuery.timeago.settings.strings = {
    prefixAgo: null,
    prefixFromNow: null,
    suffixAgo: 'ago',
    suffixFromNow: 'from now',
    seconds: 'now',
    minute: 'a minute',
    minutes: '%d minutes',
    hour: 'an hour',
    hours: '%d hours',
    day: 'a day',
    days: '%d days',
    month: 'a month',
    months: '%d months',
    year: 'a year',
    years: '%d years',
    wordSeparator: ' ',
    numbers: []
  };

  var loggedIn = false;
  var convos = new Convos.User();
  var convosFailedToload = function(err) {
    clearTimeout(convosFailedToload.tid);
    $('.loading-convos h5').html('Oh noes! Convos failed to load :(').attr('class', 'red-text');
    $('.loading-convos p').not('.rendered').html(err || 'Maybe you have a browser from last century?').attr('class', 'red-text');
  };

  window.convos = convos;
  convosFailedToload.tid = setTimeout(convosFailedToload, 5000);
  Router.start(convos.render.bind(convos));

  // email is set after a successful login, either as a result from load()
  // below or when submitting a form from user-register.tag or user-login.tag.
  convos.on('email', function(email) {
    if (loggedIn || !email) return;
    $('body .loading-convos').remove();
    Router.route(Router.url().path.match(/^(login|register|)$/) ? 'chat' : false);
    loggedIn = true;
  });

  convos.load(function(err) {
    if (err == 401) {
      $('.loading-convos').remove();
      Router.route('login');
    }
    else if (err) {
      convosFailedToload('Could not get user data. (' + err + ')');
    }
  });
})(jQuery);
