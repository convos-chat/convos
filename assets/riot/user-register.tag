<user-register>
  <div class="row not-logged-in-wrapper">
    <form onsubmit={register} class="col s10 offset-s1 m6 offset-m3">
      <div class="row">
        <div class="col s12">
          <h2>Convos</h2>
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
      <div class="row" if={errors.length}>
        <div class="col s12"><div class="alert">{errors[0].message}</div></div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <button class="btn waves-effect waves-light" type="submit">
            Register <i class="material-icons right">send</i>
          </button>
          <a href="#login" class="btn-flat waves-effect waves-light">Log in</a>
        </div>
      </div>
      <div class="row">
        <div class="col s12 about">
          &copy; <a href="http://nordaaker.com">Nordaaker</a> - <a href="http://convos.by">About</a>
        </div>
      </div>
    </form>
  </div>
  <script>

  mixin.form(this);
  mixin.http(this);

  this.user = opts.user;

  register(e) {
    localStorage.setItem('email', this.form_email.value);

    if (this.form_password.value != this.form_password_again.value) {
      $('[id^="form_password"]').addClass('invalid');
      this.errors = [{message: 'Passwords does not match'}];
      return;
    }

    this.errors = []; // clear error on post
    this.httpPost(
      apiUrl('/user/register'),
      {email: this.form_email.value, password: this.form_password.value},
      function(err, xhr) {
        if (err) return this.formInvalidInput(err).update();
        this.user.update(xhr.responseJSON);
        riot.url.route('chat');
      }
    );
  }

  this.on('mount', function() {
    if (this.user.email()) return riot.url.route('chat');
    this.form_email.value = localStorage.getItem('email');
    this.form_email.focus();
  });

  </script>
</user-register>
