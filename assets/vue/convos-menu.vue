<template>
  <a href="#notifications" @click.prevent="toggleLocation('notifications', 'chat')" data-hint="Show notifications" class="notifications">
    <i class="material-icons" :class="user.notifications.length ? 'active' : ''">{{user.notifications.length ? "notifications_active" : "notifications_none"}}</i>
    <b class="n-notifications" v-if="user.notifications.length">{{user.notifications.length < 100 ? user.notifications.length : "99+"}}</b>
  </a>
  <a href="#profile" @click.prevent="toggleLocation('profile', 'chat')" data-hint="Edit profile">
    <i class="material-icons">account_circle</i>
  </a>
  <a href="#help" @click.prevent="toggleLocation('help', 'chat')" data-hint="Help">
    <i class="material-icons">help</i>
  </a>
  <a href="#logout" @click.prevent="logout" class="btn-logout" data-hint="Logout">
    <i class="material-icons">power_settings_new</i>
  </a>
</template>
<script>
module.exports = {
  props:    ["user"],
  events: {
    locationchange: function(hash) {
      var hash = hash[0] || 'chat';
      $("header a").removeClass("active").filter('[href$="' + hash + '"]').addClass("active");
      return true;
    }
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
    }
  }
};
</script>
