<template>
  <div class="convos-login">
    <div class="row not-logged-in-wrapper">
      <form @submit.prevent="login" class="col s12 m6 offset-m3">
        <div class="row">
          <div class="col s12">
            <h2>Convos</h2>
            <p><i>- Collaboration done right.</i></p>
          </div>
        </div>
        <div class="row">
          <md-input :value.sync="email" type="email" :focus="!email" id="form_login_email">Email</md-input>
        </div>
        <div class="row">
          <md-input :value.sync="password" type="password" :focus="!!email" id="form_login_password">Password</md-input>
        </div>
        <div class="row" v-if="errors.length">
          <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
        </div>
        <div class="row">
          <div class="col s12">
            <button class="btn waves-effect waves-light" type="submit">Log in</button>
            <a href="#register" @click.prevent="user.currentPage = 'convos-register'" class="btn-flat waves-effect waves-light">Register</a>
          </div>
        </div>
        <div class="row">
          <div class="col s12 about">
            <a :href="settings.organization_url">{{settings.organization_name}}</a> - <a href="http://convos.by">About</a>
          </div>
        </div>
      </form>
    </div>
  </div>
</template>
<script>
module.exports = {
  props:    ["user"],
  data:     function() {
    return {
      email:    localStorage.getItem("email") || "",
      errors:   [],
      password: ""
    };
  },
  methods: {
    login: function() {
      var self = this;
      this.errors = [];
      localStorage.setItem("email", this.email);

      Convos.api.loginUser(
        {
          body: {
            email:    this.email,
            password: this.password
          }
        }, function(err, xhr) {
          if (err) return self.errors = err;
          self.user.refresh();
        }
      );
    }
  }
};
</script>
