<new-dialog>
  <form onsubmit={chat}>
    <div class="row">
      <div class="col s12">
        <div class="actions">
          <a href="#chat"><i class="material-icons">close</i></a>
        </div>
        <h5>New dialog</h5>
        <p>
          You can create a dialog with either a single user (by nick)
          or join a chat room (channel). Click "<a href="#load" onclick={load}>Load</a>"
          to get a list of available rooms. Note that loading the list
          from the server might take a while.
        </p>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <select name="connection_id" id="form_connection_id" onchange={connectionChanged}>
          <option value="" if={!user.connections().length}>No connections</option>
          <option selected={connection ? connection == c : !i} value={c.id()} each={c, i in user.connections()}>{c.protocol()}-{c.name()}</option>
        </select>
        <label for="form_connection_id">Select connection</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <input name="name" id="form_name" type="text" autocomplete="off" spellcheck="false">
        <div class="autocomplete">
          <ul>
            <li class="link truncate" each={rooms}><a href={name()} tabindex=-1>{name()} - {topic() || 'No topic'}</a></li>
            <li class="no-match" if={!rooms.length && noRoomsDescription}>{noRoomsDescription}</li>
          </ul>
        </div>
        <label for="form_name">Room or nick</label>
        <p if={rooms.length}>Found {rooms.length} room{rooms.length == 1 ? '' : 's'}.</p>
      </div>
    </div>
    <div class="row" if={errors.length}>
      <div class="input-field col s12"><div class="alert">{errors[0].message}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" disabled={!canSubmit}>
          Chat <i class="material-icons right">send</i>
        </button>
        <a href="#load" onclick={load} class="btn waves-effect waves-light">
          Load <i class="material-icons right">refresh</i>
        </a>
      </div>
    </div>
  </form>
  <script>
  var tag = this;

  this.user = opts.user;
  this.connection = null;
  this.noRoomsDescription = null;
  this.rooms = [];

  this.user.one('refreshed', function() {
    tag.update({connection: this.connections()[0]});
  });

  chat(e) {
    var name = this.form_name.value;
    if (!name.length) return;
    this.connection.joinDialog(name, function(err, dialog) {
      if (err) return tag.update({errors: err});
      tag.user.currentDialog(dialog);
      riot.route('chat');
    });
  }

  connectionChanged(e) {
    if (e) this.connection = this.user.connection(this.form_connection_id.value);
  }

  load(e) {
    this.noRoomsDescription = 'Loading rooms from ' + this.connection.id() + '...';
    this.connection.rooms(function(err, rooms) {
      this.noRoomsDescription = err ? err[0] : null;
      if (!err) tag.rooms = rooms;
      tag.update();
      tag.form_name.value = '';
      $(tag.form_name).autocomplete('update'); // need to happen after update()
    });
  }

  this.on('mount', function() {
    $(this.form_name).autocomplete({
      onkeyup: function(e) { tag.update({canSubmit: tag.form_name.value.length}) },
      onselect: function(e) { tag.update({canSubmit: true}) }
    });
  });
  </script>
</new-dialog>
