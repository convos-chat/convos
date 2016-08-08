<template>
  <a href="#notifications" @click.prevent="toggleLocation('notifications', 'chat')" data-hint="Show notifications">
    <i class="material-icons" :class="notifications.length ? 'active' : ''">{{notifications.length ? "notifications_active" : "notifications_none"}}</i>
    <b class="n-notifications" v-if="notifications.length">{{notifications.length < 100 ? notifications.length : "99+"}}</b>
  </a>
  <a href="#profile" @click.prevent="toggleLocation('profile', 'chat')" :class="activeClass('profile')" data-hint="Edit profile">
    <i class="material-icons">account_circle</i>
  </a>
  <a href="#help" @click.prevent="toggleLocation('help', 'chat')" :class="activeClass('help')" data-hint="Help">
    <i class="material-icons">help</i>
  </a>
  <a href="#logout" @click.prevent="logout" class="btn-logout" data-hint="Logout">
    <i class="material-icons">power_settings_new</i>
  </a>
  <a href="#menu" @click.prevent="toggleMenu" data-hint="Hide menu" class="btn-toggle-menu">
    <i class="material-icons">close</i>
  </a>
</template>
<script>
module.exports = {
  props:    ["user"],
  data:  function() {
    return {notifications: []};
  },
  methods:  {
    activeClass: function(section) {
      var hash = this.parseLocation();
      return {active: hash[0] == section};
    },
    logout: function(e) {
      var self = this;
      Convos.api.http().logoutUser({}, function(err, xhr) {
        if (err) return console.log(err); // TODO: Display error message
        self.$dispatch("logout");
      });
    },
    toggleMenu: function() {
      $("nav").hide();
    }
  }
};
</script>
