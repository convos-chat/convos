<connection-editor>
  <form onsubmit={saveConnection}>
    <div class="row">
      <div class="col s12">
        <div class="actions">
          <a href="#chat"><i class="material-icons">close</i></a>
        </div>
        <h5>Connection editor</h5>
        <p if={!user.connections().length}>
          You need to add a connection before you can have a dialogue.
          <span if={defaultServer}>
            We have filled in an example server, but you can connect to any server
            you like. "Username" and "password" are optional in most cases.
          </span>
          <span if={!defaultServer}>
            You need to fill in "server", but "username" and "password" are
            optional in most cases.
          </span>
        </p>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <select name="connection_id" id="form_connection_id" onchange={connectionChanged}>
          <option value="">Create new connection...</option>
          <option selected={connection ? connection == c : !i} value={c.id()} each={c, i in user.connections()}>{c.protocol()}-{c.name()}</option>
        </select>
        <label for="form_connection_id">Select connection</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s3">
        <select name="protocol" id="form_protocol" onchange={protocolChanged}>
          <option value="irc">IRC</option>
        </select>
        <label for="form_protocol">Protocol</label>
      </div>
      <div class="input-field col s9">
        <input name="url" id="form_url" type="text" class="validate">
        <label for="form_url">Server</label>
      </div>
    </div>
    <div class="row" if={showNickField}>
      <div class="input-field col s12">
        <input name="nick" id="form_nick" type="text" class="validate">
        <label for="form_nick">Nick</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s6">
        <input name="username" id="form_username" type="text" class="validate">
        <label for="form_username">Username</label>
      </div>
      <div class="input-field col s6">
        <input name="password" id="form_password" type="password" autocomplete="off" class="validate">
        <label for="form_password">Password</label>
      </div>
    </div>
    <div class="row" if={errors.length}>
      <div class="input-field col s12"><div class="alert">{errors[0].message}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit">
          {connection ? 'Update' : 'Create'} <i class="material-icons right">save</i>
        </button>
        <a href="#delete" onclick={removeConnection} class="btn-delete right" if={connection}>
          <i class="material-icons">delete</i>
        </a>
        <span class="grey-text text-darken-2">State: {connection ? connection.state() : 'new'}.</span>
      </div>
    </div>
  </form>
  <script>
  var tag = this;

  mixin.form(this);

  this.user = opts.user;
  this.connections = null;
  this.defaultServer = Convos.settings.default_server || '';
  this.showNickField = false;

  this.user.one('refreshed', function() {
    tag.update({connection: this.connections()[0]});
  });

  connectionChanged(e) {
    if (e) this.connection = this.user.connection(this.form_connection_id.value);
    this.errors = [];

    if (this.connection) {
      var url = this.connection.url().parseUrl();
      this.form_nick.value = url.query.nick;
      this.form_password.value = url.userinfo[1] || '';
      this.form_url.value = url.hostPort;
      this.form_username.value = url.userinfo[0] || '';
    }
    else {
      this.form_nick.value = this.user.email().split('@')[0] || 'adasd';
      this.form_password.value = '';
      this.form_url.value = this.defaultServer;
      this.form_username.value = '';
    }

    this.updateTextFields();
  }

  protocolChanged() {
    // TODO
  }

  removeConnection() {
    this.user.removeConnection(this.connection, function(err) {
      if (!err) tag.connection = this.connections()[0];
      tag.connection = this.connections()[0];
      tag.connectionChanged();
      riot.update();
    });
  }

  saveConnection(e) {
    var c = this.connection || new Convos.Connection({user: this.user});
    var userinfo = [this.form_username.value, this.form_password.value].join(':');
    var url;

    userinfo = userinfo.match(/[^:]/) ? userinfo + '@' : '';
    url = this.form_protocol.value + '://' + userinfo + this.form_url.value;
    if (this.showNickField) url += '?nick=' + this.form_nick.value;

    this.errors = []; // clear error on post
    c.url(url).save(function(err) {
      if (err) return tag.formInvalidInput(err).update();
      tag.connection = this;
      tag.connectionChanged();
      riot.update();
    });
  }

  this.on('update', function() {
    this.showNickField = this.form_protocol.value == 'irc';
    this.updateTextFields();
  });

  </script>
</connection-editor>
