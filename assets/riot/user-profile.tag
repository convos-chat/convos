<user-profile>
  <form onsubmit={submitForm} method="post" class="modal-content readable-width">
    <div class="row">
      <div class="col s12">
        <h4 class="green-text text-darken-3">Edit profile for {convos.email()}</h4>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s6">
        <input placeholder="At least six characters" name="password" id="form_password" type="password" class="validate">
        <label for="form_password">Password</label>
      </div>
      <div class="input-field col s6">
        <input placeholder="Repeat password" id="form_password_again" type="password" class="validate">
      </div>
    </div>
    <div class="row" if={formError}>
      <div class="col s12"><div class="alert">{formError}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit">Update <i class="material-icons right">save</i></button>
        <button class="btn-flat waves-effect waves-light modal-close" type="button">Close</button>
      </div>
    </div>
  </form>
  <script>

  mixin.form(this);
  mixin.http(this);

  this.convos = window.convos;

  submitForm(e) {
    localStorage.setItem('email', this.email.value);

    if (this.password.value != this.password_again.value) {
      $('[id^="form_password"]').addClass('invalid');
      this.formError = 'Passwords does not match';
      return;
    }

    this.formError = ''; // clear error on post
    this.httpPost(
      apiUrl('/user'),
      {avatar: this.avatar.value, password: this.password.value},
      function(err, xhr) {
        if (err) return this.httpInvalidInput(err);
        this.convos.save(xhr.responseJSON);
      }
    );
  }

  this.on('mount', function() {
    this.updateTextFields();
    setTimeout(function() { this.email.focus(); }.bind(this), 300);
  });

  </script>
</user-profile>
