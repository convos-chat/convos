<sidenav-settings>
  <div class="collection">
    <a each={connections} href="#edit-connection" onclick={parent.editConnection} class="collection-item">
      <i class="material-icons">device_hub</i> {this.protocol()} {this.name()}
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

  this.connections = [];
  this.convos = window.convos;

  editConnection(e) {
    this.openModal(e.currentTarget.href.split('#')[1], e.item ? {connection: e.item} : {next: 'add-conversation'});
  }

  editProfile(e) {
    this.openModal('user-profile', {});
  }

  this.on('mount', function() {
    this.convos.connections(function(err, connections) { this.connections = connections; this.update(); }.bind(this));
  });

  </script>
</sidenav-settings>
