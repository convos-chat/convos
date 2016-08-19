<template>
  <div class="convos-profile is-sidebar">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <convos-header-links :user="user"></convos-header-links>
    </header>
    <div class="content">
      <div class="row">
        <div class="col s12">
          <h5 class="truncate">{{user.email}}</h5>
        </div>
      </div>
      <div class="row">
        <md-input :value.sync="password" type="password" placeholder="At least six characters">Password</md-input>
        <md-input :value.sync="passwordAgain" type="password">Repeat password</md-input>
      </div>
      <div class="row">
        <div class="col s12">
          <input v-model="notifications" type="checkbox" class="filled-in" id="form_notifications" :checked="settings.notifications == 'granted'" value="granted">
          <label for="form_notifications">Enable notifications</label>
        </div>
      </div>
      <div class="row" v-if="errors.length">
        <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
      </div>
      <div class="row">
        <div class="col s12">
          <button @click="save" class="btn waves-effect waves-light" type="submit">Update <i class="material-icons right">save</i></button>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data:  function() {
    return {errors: [], password: "", passwordAgain: "", notifications: Notification.permission};
  },
  methods: {
    save: function() {
      var self = this;

      if (this.password != this.passwordAgain)
        return this.errors = [{message: "Passwords does not match"}];
      if (this.notifications && this.notifications != this.settings.notifications)
        this.enableNotifications(true);
      if (!this.notifications)
        this.enableNotifications(false);

      if (this.password) {
        Convos.api.updateUser({body: {password: this.password}}, function(err, res) {
          if (err) self.errors = err;
        });
      }
    }
  }
};
</script>
