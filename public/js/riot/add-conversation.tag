<add-conversation>
  <form onsubmit={submitForm} method="post" class="modal-content readable-width">
    <div class="row">
      <div class="col s12">
        <h4 class="green-text text-darken-3">Add conversation</h4>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <select name="connection" id="form_connection">
          <option each={obj, i in opts.connections} value={obj.path()}>{obj.type()} - {obj.name()}</option>
        </select>
        <label for="form_connection">Connection</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <input name="name" id="form_name" type="text">
        <label for="form_name">Name</label>
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

  mixin.form(this);
  mixin.http(this);
  mixin.modal(this);

  submitForm(e) {
    e.preventDefault();
    this.formError = ''; // clear error on post
    this.httpPost(
      apiUrl('/conversation/TODO'),
      {
        connection_id: this.form_connection.value,
        name: this.form_name.value,
      },
      function(err, xhr) {
        this.httpInvalidInput(xhr.responseJSON);
        convos.render(this);
        if (!err) return;
        convos.conversation(false, false, xhr.responseJSON);
        this.closeModal();
      }
    );
  }

  this.on('mount', function() {
    Materialize.updateTextFields();
    $('select', this.root).material_select();
    setTimeout(function() { this.form_name.focus(); }.bind(this), 300);
  });
</add-conversation>
