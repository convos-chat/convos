<sidenav-settings>
  <div class="collection">
    <a href="#edit-connection" title={this.state()} onclick={parent.editConnection} class="collection-item" each={connections}>
      <i class={parent.connectionClasses(this)}>device_hub</i> {this.protocol()} {this.name()}
    </a>
    <a href="#add-connection" onclick={editConnection} class="collection-item">
      <i class="material-icons">device_hub</i> Add connection...
    </a>
    <a href="#profile" onclick={editProfile} class="collection-item">
      <i class="material-icons">account_circle</i> Edit profile
    </a>
    <a href="#logout" class="collection-item">
      <i class="material-icons">power_settings_new</i> Logout
    </a>
  </div>
  <script>

  mixin.modal(this);

  this.user = opts.user;
  this.connections = [];

  connectionClasses(c) {
    return 'material-icons state-' + c.state();
  }

  editConnection(e) {
    var opts = {connection: e.item, user: this.user};
    if (!e.item) opts.next = 'add-conversation';
    this.openModal(e.currentTarget.href.split('#')[1], opts);
  }

  editProfile(e) {
    this.openModal('user-profile', {user: this.user});
  }

  this.on('mount', function() {
    this.user.connections(function(err, connections) { this.connections = connections; this.update(); }.bind(this));
  });

  </script>
</sidenav-settings>
