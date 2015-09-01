<edit-connection>
  <form onsubmit={saveConnection} method="post" class="modal-content readable-width">
    <div class="row">
      <div class="col s12">
        <h4 class="green-text text-darken-3">Edit {protocol} connection</h4>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <input id="form_server" value={url.hostPort()} type="text">
        <label for="form_server">Server</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s6">
        <input id="form_username" value={url.userinfo().split(':')[0]} type="text">
        <label for="form_username">Credentials</label>
      </div>
      <div class="input-field col s6">
        <input id="form_password" placeholder="Password" type="password" value={url.userinfo().split(':')[1]} autocomplete="off">
      </div>
    </div>
    <div class="row" if={errors.length}>
      <div class="col s12"><div class="alert">{errors[0].message}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit" disabled={saving}>Save <i class="material-icons right">save</i></button>
        <button class="btn-flat waves-effect waves-light modal-close" type="button">Close</button>
        <a href="#TODO" class="btn waves-effect waves-light red right" disabled={saving}><i class="material-icons">delete</i></a>
      </div>
    </div>
  </form>
  <script>
  var tag = this;

  mixin.form(this);
  mixin.modal(this);

  this.connection = opts.connection;
  this.url = this.connection.url();
  this.user = opts.user;

  saveConnection(e) {
    this.errors = []; // clear error on post
    this.saving = true;
    this.connection.url().hostPort(this.form_server.value);
    this.connection.url().userinfo(this.form_username.value, this.form_password.value);

    this.connection.save(function(err) {
      if (err) return tag.formInvalidInput(err).update();
      tag.closeModal();
      riot.update();
    });
  }

  this.on('mount', function() {
    this.updateTextFields();
    this.form_server.focus();
  });

  </script>
</edit-connection>
