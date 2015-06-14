<add-connection>
  <form onsubmit={submitForm} method="post" class="modal-content readable-width">
    <div class="row">
      <div class="col s12">
        <h4 class="green-text text-darken-3">Add connection</h4>
        <p if={opts.first}>
          You need to add a connection before you can start a conversation.
        </p>
        <p if={defaultServer}>
          We have filled in an example server, but you can connect to any server you like.
        </p>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s3">
        <select name="protocol" id="form_protocol">
          <option value="IRC">IRC</option>
        </select>
        <label for="form_protocol">Protocol</label>
      </div>
      <div class="input-field col s9">
        <input name="server" id="form_server" placeholder="chat.freenode.net:6697" type="text" value={defaultServer}>
        <label for="form_server">Server</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s6">
        <input name="username" id="form_username" placeholder="Username" type="text">
        <label for="form_username">Credentials</label>
      </div>
      <div class="input-field col s6">
        <input name="password" id="form_password" placeholder="Password" type="password" autocomplete="off">
      </div>
    </div>
    <div class="row" if={formError}>
      <div class="col s12"><div class="alert">{formError}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit">
          Add <i class="mdi-content-send right"></i>
        </button>
        <button class="btn-flat waves-effect waves-light modal-close" type="submit">
          Close
        </button>
      </div>
    </div>
  </form>
  <script>

  mixin.form(this.prototype);
  mixin.http(this.prototype);
  mixin.modal(this.prototype);

  this.defaultServer = 'localhost'; // 'chat.freenode.net:6697';

  submitForm(e) {
    e.preventDefault();
    this.formError = ''; // clear error on post
    this.httpPost(
      apiUrl('/connection'),
      {
        password: this.form_password.value,
        protocol: this.form_protocol.value,
        server:   this.form_server.value,
        username: this.form_username.value
      },
      function(err, xhr) {
        this.httpInvalidInput(xhr.responseJSON);
        convos.render(this);
        if (!err) return;
        convos.connection(false, false, xhr.responseJSON);
        this.openModal(opts.next || 'edit-connection', xhr.responseJSON);
      }
    );
  }

  this.on('mount', function() {
    Materialize.updateTextFields();
    $('select', this.root).material_select();
    setTimeout(function() { this.form_server.focus(); }.bind(this), 300);
  });

  </script>
</add-connection>
