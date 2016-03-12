<dialog-message-users>
  <h5 class="title">Participants ({users.length})</h5>
  <span if={!users.length}>No participants. You need to join the dialog first.</span>
  <a href={'#insert:' + u.name} each={u, i in users}>
    {u.mode}{u.name}{i+1 == users.length ? '.' : ', '}
  </a>
  <span class="secondary-content">
    <a href="#close" onclick={parent.removeMessage}><i class="material-icons">close</i></a>
  </span>
  <script>
  this.users = [];

  this.on('update', function() {
    var users = opts.dialog.users()
    this.users = Object.keys(users).sort().map(function(name) { return users[name]; });
  });
  </script>
</dialog-message-users>
