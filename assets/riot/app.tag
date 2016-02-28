<app>
  <chat if={render == 'chat'}>
    <nav>
      <sidebar-notifications user={user}></sidebar-notifications>
      <sidebar-dialogs user={user}></sidebar-dialogs>
      <sidebar-settings user={user}></sidebar-settings>
    </nav>
    <connection-editor user={user} if={modal == 'connections'}></connection-editor>
    <new-dialog user={user} if={modal == 'new-dialog'}></new-dialog>
    <dialog-container user={user}></dialog-container>
  </chat>
  <user-login user={user} errors={errors} if={render == 'login'}/></user-login>
  <user-register user={user} if={render == 'register'}></user-register>
  <not-found if={render == 'not-found'}></not-found>
  <script>
  var tag = this;

  this.errors = opts.errors;
  this.user = opts.user;
  this.modal = '';
  this.render = '';

  this.user.on('refreshed', function() { riot.update() });

  riot.route('/logout', function() {
    if (!tag.user.email()) return tag.update({render: 'login'});
    Convos.ws.close(); // cannot use ws when logging out
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
    tag.update({render: 'chat', modal: ''});
  });

  riot.route('/settings/*', function(modal) {
    if (!tag.user.email()) return riot.route('login', 'Login', true);
    tag.update({render: 'chat', modal: modal});
  });

  riot.route('/', function() {
    riot.route(tag.user.email() ? 'chat' : 'login');
  });

  riot.route('/..', function() {
    tag.update({render: 'not-found'});
  });

  this.on('mount', function() {
    riot.route.start(true);
  });

  this.on('updated', function() {
    $('select').material_select();
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
  });

  </script>
</app>
