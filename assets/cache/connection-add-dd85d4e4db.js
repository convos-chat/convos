riot.tag2('connection-add', '<form onsubmit="{addConnection}" method="post" class="modal-content readable-width"> <div class="row"> <div class="col s12"> <h4 class="green-text text-darken-3">Add connection</h4> <p if="{opts.first}"> You need to add a connection before you can start a conversation. </p> <p if="{defaultServer}"> We have filled in an example server, but you can connect to any server you like. </p> </div> </div> <div class="row"> <div class="input-field col s3"> <select name="protocol" id="form_protocol"> <option value="irc">IRC</option> </select> <label for="form_protocol">Protocol</label> </div> <div class="input-field col s9"> <input name="server" id="form_server" placeholder="chat.freenode.net:6697" type="text" value="{defaultServer}"> <label for="form_server">Server</label> </div> </div> <div class="row"> <div class="input-field col s6"> <input name="username" id="form_username" placeholder="Username" type="text"> <label for="form_username">Credentials</label> </div> <div class="input-field col s6"> <input name="password" id="form_password" placeholder="Password" type="password" autocomplete="off"> </div> </div> <div class="row" if="{errors.length}"> <div class="col s12"><div class="alert">{errors[0].message}</div></div> </div> <div class="row"> <div class="input-field col s12"> <button class="btn waves-effect waves-light" type="submit"> Add <i class="material-icons right">send</i> </button> <button class="btn-flat waves-effect waves-light modal-close" type="submit"> Close </button> </div> </div> </form>', '', '', function(opts) {
  var tag = this;

  mixin.form(this);
  mixin.modal(this);

  this.user = opts.user;
  this.defaultServer = Convos.settings.default_server;
  this.nextModal = opts.next || 'connection-edit';

  this.addConnection = function(e) {
    var c = new Convos.Connection({user: this.user});

    c.url().hostPort(this.form_server.value);
    c.url().scheme(this.form_protocol.value.toLowerCase());
    c.url().userinfo(this.form_username.value, this.form_password.value);

    this.errors = [];
    c.save(function(err) {
      if (err) return tag.formInvalidInput(err).update();
      tag.openModal(tag.nextModal, {connection: this, user: tag.user});
      riot.update();
    });
  }.bind(this)

  this.on('mount', function() {
    this.updateTextFields();
    $('select', this.root).material_select();
    this.form_server.focus();
  });

}, '{ }');
