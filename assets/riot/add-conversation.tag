<add-conversation>
  <form onsubmit={submitForm} method="post" class="modal-content readable-width">
    <div class="row">
      <div class="col s12">
        <h4 class="green-text text-darken-3">Create conversation</h4>
        <p>
          A conversation is either the name of a person or a chat room.
        </p>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <select name="connection" id="form_connection">
          <option each={obj, i in opts.connections} value={i}>{obj.protocol()} - {obj.name()}</option>
        </select>
        <label for="form_connection">Connection</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <input name="name" id="form_name" type="text" autocomplete="off" spellcheck="false">
        <div class="autocomplete">
          <ul>
            <li each={obj, i in rooms} class="link"><a href={obj.name()} tabindex=-1>{obj.name()} - {obj.topic() || 'No topic'}</a></li>
            <li class="no-match">{noRoomsDescription}</li>
          </ul>
        </div>
        <label for="form_name">Name</label>
      </div>
    </div>
    <div class="row" if={errors.length}>
      <div class="col s12"><div class="alert">{errors[0].message}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit">
          Chat <i class="material-icons right">send</i>
        </button>
        <button class="btn-flat waves-effect waves-light modal-close" type="submit">
          Close
        </button>
      </div>
    </div>
  </form>
  <script>

  mixin.form(this);
  mixin.modal(this);

  this.noRoomsDescription = 'Loading rooms from ' + opts.connections[0].name() + '...';
  this.rooms = [];

  changeConnection() {
    this.selectedConnection().rooms(function(err, rooms) {
      if (err) throw err;
      this.rooms = rooms;
      this.noRoomsDescription = 'No rooms found.';
      this.update();
      $('input[name="name"]', this.root).autocomplete('update'); // need to happen after this.update()
    }.bind(this));
  };

  selectedConnection() {
    var $option = $('option:selected, option:first', this.connection).eq(0);
    return this.opts.connections[$option.val()];
  }

  submitForm(e) {
    this.errors = []; // clear error on post
    this.selectedConnection().joinConversation(this.form_name.value, function(err) {
      if (!err) return this.closeModal();
      this.update({errors: err});
    }.bind(this));
  }

  this.on('mount', function() {
    setTimeout(function() { this.form_name.focus(); }.bind(this), 300);
    this.updateTextFields();
    $('input[name="name"]', this.root).autocomplete();
    $('select', this.root).material_select();
    $(this.connection).change(this.changeConnection.bind(this)).change();
  });

  </script>
</add-conversation>
