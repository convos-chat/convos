<template>
  <convos-not-logged-in screen="login" :user="user" @submit="login">
    <div class="row">
      <md-input :value.sync="email" type="email" :focus="!email" id="form_login_email">Email</md-input>
    </div>
    <div class="row">
      <md-input :value.sync="password" type="password" :focus="!!email" id="form_login_password">Password</md-input>
    </div>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
  </convos-not-logged-in>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {
      email: localStorage.getItem("email") || "",
      errors: [],
      password: ""
    };
  },
  methods: {
    login: function() {
      var self = this;
      this.errors = [];
      localStorage.setItem("email", this.email);
      Convos.api.loginUser(
        {body: {email: this.email, password: this.password}},
        function(err, xhr) {
          if (err) return self.errors = err;
          self.user.refresh();
        }
      );
    }
  }
};
</script>
