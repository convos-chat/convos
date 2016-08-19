<template>
  <div class="convos-register">
    <div class="row not-logged-in-wrapper">
      <form @submit.prevent="register" class="col s12 m6 offset-m3">
        <div class="row">
          <div class="col s12">
            <h2>Convos</h2>
            <p><i>- Collaboration done right.</i></p>
          </div>
        </div>
        <div class="row">
          <md-input :value.sync="email" :focus="true">Email</md-input>
        </div>
        <div class="row">
          <md-input :value.sync="password" cols="s6" type="password">Password</md-input>
          <md-input :value.sync="passwordAgain" cols="s6" type="password" placeholder="Repeat password"></md-input>
        </div>
        <div class="row" v-if="settings.invite_code">
          <md-input :value.sync="invite_code" type="password">Invite code</md-input>
        </div>
        <div class="row" v-if="errors.length">
          <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
        </div>
        <div class="row">
          <div class="input-field col s12">
            <button class="btn waves-effect waves-light" type="submit">
              Register <i class="material-icons right">send</i>
            </button>
            <a href="#login" @click.prevent="currentPage = 'convos-login'" class="btn-flat waves-effect waves-light">Log in</a>
          </div>
        </div>
        <div class="row">
          <div class="col s12 about">
            &copy; <a href="http://nordaaker.com">Nordaaker</a> - <a href="http://convos.by">About</a>
          </div>
        </div>
      </form>
    </div>
  </div>
</template>
<script>
module.exports = {
  props:    ["currentPage", "user"],
  data:     function() {
    return {
      invite_code:   "",
      email:         localStorage.getItem("email"),
      errors:        [],
      password:      "",
      passwordAgain: "",
    };
  },
  methods: {
    register: function() {
      var self = this;
      this.errors = [];
      localStorage.setItem("email", this.email);

      if (!this.password || this.password != this.passwordAgain) {
        return this.errors = [{message: "Passwords does not match"}];
      }

      Convos.api.registerUser(
        {
          body: {
            invite_code: this.invite_code,
            email: this.email,
            password: this.password
          }
        }, function(err, xhr) {
          if (err) return self.errors = err;
          self.$dispatch("login", xhr.body);
        }.bind(this)
      );
    }
  }
};
</script>
