<edit-connection>
  <form onsubmit={submitForm} method="post" class="modal-content readable-width">
    <div class="row">
      <div class="col s12">
        <h4 class="green-text text-darken-3">Edit {connection.protocol()} connection</h4>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <input name="server" id="form_server" placeholder={connection.url()} value={parseURL(connection.url()).host_port} type="text">
        <label for="form_server">Server</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s6">
        <input name="username" id="form_username" placeholder={connection.username()} value={connection.username()} type="text">
        <label for="form_username">Credentials</label>
      </div>
      <div class="input-field col s6">
        <input name="password" id="form_password" placeholder="Password" type="password" autocomplete="off">
      </div>
    </div>
    <div class="row" if={errors.length}>
      <div class="col s12"><div class="alert">{errors[0].message}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit">Save <i class="material-icons right">save</i></button>
        <button class="btn-flat waves-effect waves-light modal-close" type="button">Close</button>
        <a href="#TODO" class="btn waves-effect waves-light red right"><i class="material-icons">delete</i></a>
      </div>
    </div>
  </form>
  <script>

  mixin.form(this);
  mixin.modal(this);

  this.connection = opts.connection;
  this.user = opts.user;

  submitForm(e) {
    var url = parseURL(this.connection.url());
    url.host = this.server.value.split(':')[0];
    url.port = this.server.value.split(':')[1];
    this.errors = []; // clear error on post
    this.connection.save(
      {
        password: this.password.value,
        url:      url.toString(),
        username: this.username.value
      },
      function(err, xhr) {
        this.formInvalidInput(xhr.responseJSON);
        if (!err) return;
        this.user.connection(false, false, xhr.responseJSON);
        this.openModal(opts.next || 'edit-connection', xhr.responseJSON);
      }
    );
  }

  this.on('mount', function() {
    this.updateTextFields();
    setTimeout(function() { this.server.focus(); }.bind(this), 300);
  });

  </script>
</edit-connection>
