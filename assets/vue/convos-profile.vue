<template>
  <div class="convos-profile is-sidebar">
    <header>
      <convos-menu :user="user">
        <convos-toggle-dialogs :user="user"></convos-toggle-dialogs>
      </convos-menu>
    </header>
    <div class="content">
      <div class="row">
        <div class="col s12">
          <h5 class="truncate">{{user.email}}</h5>
        </div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <input id="form_password" type="password" class="validate" placeholder="At least six characters">
          <label for="form_password">Password</label>
        </div>
        <div class="input-field col s12">
          <input placeholder="Repeat password" id="form_password_again" type="password" class="validate">
        </div>
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
        <div class="input-field col s12">
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
    return {errors: [], notifications: Notification.permission};
  },
  methods: {
    save: function() {
      if (this.notifications && this.notifications != this.settings.notifications) {
        this.enableNotifications(true);
      }
      if (!this.notifications) {
        this.enableNotifications(false);
      }
    }
  }
};
</script>
