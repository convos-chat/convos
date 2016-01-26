riot.tag2('connection-edit', '<form onsubmit="{saveConnection}" method="post" class="modal-content readable-width" if="{!deleting}"> <div class="row"> <div class="col s12"> <h4 class="green-text text-darken-3">Edit {connection.protocol()} connection</h4> </div> </div> <div class="row"> <div class="input-field col s12"> <input id="form_server" value="{url.hostPort()}" type="text"> <label for="form_server">Server</label> </div> </div> <div class="row"> <div class="input-field col s6"> <input id="form_username" value="{url.userinfo().split(\':\')[0]}" type="text"> <label for="form_username">Credentials</label> </div> <div class="input-field col s6"> <input id="form_password" placeholder="Password" type="password" value="{url.userinfo().split(\':\')[1]}" autocomplete="off"> </div> </div> <div class="row" if="{errors.length}"> <div class="col s12"><div class="alert">{errors[0].message}</div></div> </div> <div class="row"> <div class="input-field col s12"> <button class="btn waves-effect waves-light" type="submit" __disabled="{saving}">Save <i class="material-icons right">save</i></button> <button class="btn-flat waves-effect waves-light modal-close" type="button">Close</button> <a href="#delete" onclick="{deleteConnection}" class="btn waves-effect waves-light red right" __disabled="{saving}"><i class="material-icons">delete</i></a> </div> </div> </form> <form onsubmit="{deleteConnection}" method="post" class="modal-content readable-width" if="{deleting}"> <div class="row"> <div class="col s12"> <h4 class="green-text text-darken-3">Delete {connection.protocol()} connection</h4> <p>Are you sure you want to delete the connection?</p> <p>Doing so will remove all conversation history and delete all settings.</p> </div> </div> <div class="row"> <div class="input-field col s12 right-align"> <button type="button" class="btn waves-effect waves-light" __disabled="{saving}" onclick="{keepConnection}">No</button> <button type="submit" class="btn waves-effect red waves-light" __disabled="{saving}">Yes <i class="material-icons right">delete</i></button> </div> </div> </form>', '', '', function(opts) {
  var tag = this;

  mixin.form(this);
  mixin.modal(this);

  this.connection = opts.connection;
  this.deleting = 0;
  this.url = this.connection.url();
  this.user = opts.user;

  this.deleteConnection = function(e) {
    if (!(this.deleting++)) return;
    var c = this.connection;
    this.errors = [];
    this.saving = true;
    this.user.removeConnection(c, function(err) {
      if (err) return tag.formInvalidInput(err).update();
      tag.closeModal();
    });
  }.bind(this)

  this.keepConnection = function(e) {
    this.deleting = 0;
  }.bind(this)

  this.saveConnection = function(e) {
    this.errors = [];
    this.saving = true;
    this.connection.url().hostPort(this.form_server.value);
    this.connection.url().userinfo(this.form_username.value, this.form_password.value);

    this.connection.save(function(err) {
      if (err) return tag.formInvalidInput(err).update();
      tag.formSaved();
      riot.update();
    });
  }.bind(this)

  this.on('mount', function() {
    this.updateTextFields();
    this.form_server.focus();
  });

}, '{ }');
