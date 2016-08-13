<template>
  <div class="menu">
    <slot></slot>
    <template v-if="!toggle || !settings.sidebar">
      <a v-sidebar.literal="#notifications" data-hint="Show notifications" class="notifications" :class="activeClass">
        <i class="material-icons" :class="user.notifications.length ? 'active' : ''">{{user.notifications.length ? "notifications_active" : "notifications_none"}}</i>
        <b class="n-notifications" v-if="user.notifications.length">{{user.notifications.length < 100 ? user.notifications.length : "99+"}}</b>
      </a>
      <a v-sidebar.literal="#profile" data-hint="Edit profile" :class="activeClass">
        <i class="material-icons">account_circle</i>
      </a>
      <a v-sidebar.literal="#help" data-hint="Help" :class="activeClass">
        <i class="material-icons">help</i>
      </a>
      <a href="#logout" @click.prevent="logout" class="btn-logout" data-hint="Logout">
        <i class="material-icons">power_settings_new</i>
      </a>
    </template>
  </div>
</template>
<script>
module.exports = {
  props:    ["toggle", "user"],
  methods:  {
    logout: function(e) {
      var self = this;
      Convos.api.http().logoutUser({}, function(err, xhr) {
        if (err) return console.log(err); // TODO: Display error message
        self.$dispatch("logout");
      });
    }
  }
};
</script>
