<template>
  <div class="convos-message password-prompt">
    <div class="row">
      <div class="col m12">
        <h4>Password protected</h4>
        <p>This dialog require a secret password to join.</p>
      </div>
    </div>
    <div class="row">
      <md-input type="password" :value.sync="password" @keydown="errors = []" @keyup.enter="join" cols="s8 m9" :focus="true">Password</md-input>
      <div class="col input-field s4 m3">
        <button @click="join" class="btn waves-effect waves-light" :disabled="!password.length">Join</button>
      </div>
    </div>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">Invalid password. Please try again.</div></div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"],
  data: function() {
    return {errors: [], password: ""};
  },
  methods: {
    join: function() {
      var self = this;
      if (!this.password.length) return;
      this.errors = [];
      this.dialog.connection().send(
        "/join " + this.dialog.name + " " + this.password,
        this.dialog,
        function(res) {
          self.errors = res.errors || [];
          if (self.errors.length) return;
          self.dialog.reset = true;
          self.dialog.load({}, function() {});
        }
      );
    }
  }
};
</script>
