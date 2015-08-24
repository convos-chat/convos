<app>
  <chat user={user} if={render == 'chat'}/>
  <user-login user={user} errors={errors} if={render == 'login'}/>
  <user-register user={user} if={render == 'register'}/>
  <script>

  this.errors = opts.errors;
  this.render = riot.url.path.split('/')[0] || 'chat';
  this.user = opts.user;

  var tag = this;

  if (this.render == 'chat' && opts.errors.length) {
    this.render = 'login';
  }

  riot.url.on('update', function(url) {
    var current = riot.url.path.split('/')[0];

    if (current != tag.render && (!current || current.match(/^(login|register)/))) {
      if (tag.user.email()) return riot.route('chat');
      tag.update({render: current || 'login'});
    }

    $('select').material_select();
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
  });

  </script>
</app>
