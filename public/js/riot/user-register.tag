<user-register>
  <div class="row">
    <form onsubmit={submitForm} method="post" class="col s10 offset-s1 m6 offset-m3 z-depth-1">
      <div class="row">
        <div class="col s12">
          <h2 class="teal-text darken-4">Convos</h2>
          <p><i>- Collaberation done right.</i></p>
        </div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <input placeholder="susan@example.com" name="email" id="form_email" type="email" class="validate">
          <label for="form_email">Email</label>
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
          <button class="btn waves-effect waves-light" type="submit">
            Register
            <i class="mdi-content-send right"></i>
          </button>
          <a href="#login" class="btn-flat waves-effect waves-light">Log in</a>
        </div>
      </div>
    </form>
    <div class="col s10 offset-s1 m6 offset-m3 about">
      &copy; <a href="http://nordaaker.com">Nordaaker</a> - <a href="http://convos.by">About</a>
    </div>
  </div>

  mixin.form(this);
  mixin.http(this);

  submitForm(e) {
    e.preventDefault();
    localStorage.setItem('email', this.form_email.value);

    if (this.form_password.value != this.form_password_again.value) {
      $('[id^="form_password"]').addClass('invalid');
      this.formError = 'Passwords does not match';
      return;
    }

    this.formError = ''; // clear error on post
    this.httpPost(
      apiUrl('/user/register'),
      {email: this.form_email.value, password: this.form_password.value},
      function(err, xhr) {
        this.httpInvalidInput(xhr.responseJSON);
        convos.updateUser(xhr.responseJSON);
        if (convos.email()) return Router.route('chat');
        convos.afterRender();
        this.update();
      }
    );
  }

  this.on('mount', function() {
    if (convos.email()) return Router.route('chat');
    this.form_email.value = localStorage.getItem('email');
    this.form_email.focus();
  });
</user-register>
