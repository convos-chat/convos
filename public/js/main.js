(function($) {
  Router.add(/^register$/, 'user-register');
  Router.add(/^login$/,    'user-login');
  Router.add(/.?/,         'user-login');

  setTimeout(function() {
    $('.loading-convos h5').html('Oh noes! Convos failed to load :(').attr('class', 'red-text');
    $('.loading-convos p').html('Maybe you have a browser from last century?').attr('class', 'red-text');
  }, 5000);

  $(document).ready(function() {
    window.convos = mixin.convos({});
    convos.httpGet(apiUrl('/user'), {}, function(err, xhr) {
      $('.loading-convos').remove();
      this.updateUser(xhr.responseJSON);
      Router.start(convos.afterRender.bind(convos));
      Router.route(Router.url().path ? '' : err ? 'login' : 'chat');
    });
  });
})(jQuery);
