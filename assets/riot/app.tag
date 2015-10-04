<app>
  <chat user={user} if={render == 'chat'}/>
  <user-login user={user} errors={errors} if={render == 'login'}/>
  <user-register user={user} if={render == 'register'}/>
  <script>

  var tag = this;

  this.errors = opts.errors;
  this.render = riot.url.fragment().split('/')[0] || 'chat';
  this.user = opts.user;
  this.user.on('email', function(v) { tag.update({render: v ? 'chat' : 'login'}); });

  logout() {
    this.user.logout(function(err) {
      tag.update({errors: err || [{message: 'Logged out.'}], render: 'login'});
    });
  }

  renderView(url) {
    var current = url.fragment().split('/')[0];

    if (current == 'logout') {
      tag.logout();
    }
    else if (current != tag.render && (!current || current.match(/^(login|register)/))) {
      if (tag.user.email()) return riot.route('chat');
      tag.update({errors: [], render: current || 'login'});
    }

    $('select').material_select();
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
  });

  riot.url.on('update', function(url) { tag.renderView(url) });
  this.renderView(riot.url);

  </script>
</app>
