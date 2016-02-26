<user-profile>
  <form onsubmit={submitForm} method="post" class="modal-content readable-width">
    <div class="row">
      <div class="col s12">
        <h4 class="green-text text-darken-3">Edit profile for {user.email()}</h4>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s6">
        <input id="form_password" type="password" class="validate" placeholder="At least six characters">
        <label for="form_password">Password</label>
      </div>
      <div class="input-field col s6">
        <input placeholder="Repeat password" id="form_password_again" type="password" class="validate">
      </div>
    </div>
    <div class="row" if={errors.length}>
      <div class="col s12"><div class="alert">{errors[0].message}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit">Update <i class="material-icons right">save</i></button>
        <button class="btn-flat waves-effect waves-light modal-close" type="button">Close</button>
      </div>
    </div>
  </form>
  <script>

  var tag = this;
  this.user = opts.user;
  mixin.form(this);

  submitForm(e) {
    var attrs = {password: ''};

    if (this.form_password.value == this.form_password_again.value) {
      attrs.password = this.form_password_again.value;
    }
    else {
      $('[id^="form_password"]').addClass('invalid');
      this.errors = [{message: 'Passwords does not match'}];
      return;
    }

    this.errors = []; // clear error on post
    this.user.save(attrs, function(err) {
      if (err) return tag.formInvalidInput(err).update();
      tag.user.update(attrs);
      riot.route('');
    });
  }

  this.on('mount', function() {
    this.updateTextFields();
    this.form_password.focus();
  });

  </script>
</user-profile>
