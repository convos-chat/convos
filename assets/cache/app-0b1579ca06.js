riot.tag2('app', '<chat user="{user}" if="{render == \'chat\'}"></chat> <user-login user="{user}" errors="{errors}" if="{render == \'login\'}"></user-login></user-login> <user-register user="{user}" if="{render == \'register\'}"></user-register> <not-found if="{render == \'not-found\'}"></not-found>', '', '', function(opts) {

  var tag = this;

  this.errors = opts.errors;
  this.render = '';
  this.user = opts.user;

  riot.route('/logout', function() {
    if (!tag.user.email()) return tag.update({render: 'login'});
    Convos.ws.close();
    tag.user.logout(function(err) {
      tag.update({errors: err || [{message: 'Logged out.'}], render: 'login'});
    });
  })

  riot.route('/login', function() {
    if (tag.user.email()) return riot.route('chat', 'Chat', true);
    tag.update({errors: [], render: 'login'});
  })

  riot.route('/register', function() {
    if (tag.user.email()) return riot.route('chat', 'Chat', true);
    tag.update({errors: [], render: 'register'});
  })

  riot.route('/chat', function() {
    if (!tag.user.email()) return riot.route('login', 'Login', true);
    tag.update({render: 'chat'});
  });

  riot.route('/', function() {
    riot.route(tag.user.email() ? 'chat' : 'login');
  });

  riot.route('/..', function() {
    tag.update({render: 'not-found'});
  });

  this.on('mount', function() {
    riot.route(this.user.email() ? 'chat' : 'login');
    riot.route.start(true);
  });

  this.on('updated', function() {
    $('select').material_select();
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
  });

}, '{ }');
