<template>
  <div class="convos-chat">
    <convos-dialogs :user="user"></convos-dialogs>
    <convos-dialog-container :dialog="d" :sidebar="sidebar" :user="user" v-show="d.active()" v-for="d in user.dialogs"></convos-dialog-container>
    <component :is="sidebar" :settings="settings" :user="user" v-if="sidebar"></component>
  </div>
</template>
<script>
module.exports = {
  props: ["settings", "user"],
  data:  function() {
    return {
      sidebar: "",
      sidebars: {
        help: true,
        notifications: true,
        profile: true
      }
    };
  },
  events: {
    locationchange: function(hash) {
      this.sidebar = hash[0] && this.sidebars[hash[0]] ? "convos-" + hash[0] : "";
      return true;
    }
  }
};
</script>
