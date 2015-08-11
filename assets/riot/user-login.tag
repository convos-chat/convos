<user-login>
  <div class="row">
    <form onsubmit={login} class="col s10 offset-s1 m6 offset-m3 z-depth-1">
      <div class="row">
        <div class="col s12">
          <h2>Convos</h2>
          <p><i>- Collaberation done right.</i></p>
        </div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <input placeholder="susan@example.com" name="email" id="form_email" type="email" class="tooltipped validate">
          <label for="form_email">Email</label>
        </div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <input placeholder="At least six characters" name="password" id="form_password" type="password" class="tooltipped validate">
          <label for="form_password">Password</label>
        </div>
      </div>
      <div class="row" if={formError}>
        <div class="col s12"><div class="alert">{formError}</div></div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <button class="btn waves-effect waves-light" type="submit" name="action">
            Log in <i class="material-icons right">send</i>
          </button>
          <a href="#register" class="btn-flat waves-effect waves-light">Register</a>
        </div>
      </div>
    </form>
    <div class="col s10 offset-s1 m6 offset-m3 about">
      &copy; <a href="http://nordaaker.com">Nordaaker</a> - <a href="http://convos.by">About</a>
    </div>
  </div>
  <script>

  mixin.form(this);
  mixin.http(this);

  this.convos = window.convos;

  login(e) {
    this.formError = ''; // clear error on post
    localStorage.setItem('email', this.form_email.value);
    this.httpPost(
      apiUrl('/user/login'),
      {email: this.form_email.value, password: this.form_password.value},
      function(err, xhr) {
        if (!err) return this.convos.save(xhr.responseJSON);
        err.forEach(function(i) { if (i.path == '/') i.path = '/email' });
        this.httpInvalidInput(err);
      }
    );
  }

  this.on('mount', function() {
    if (this.convos.email()) return Router.route('chat');
    this.form_email.value = localStorage.getItem('email');
    this.form_email.focus();
  });

  </script>
</user-login>
