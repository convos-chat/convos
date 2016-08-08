<template>
  <div class="convos-chat">
    <nav>
      <convos-settings :user="user"></convos-settings>
      <convos-dialogs :user="user"></convos-dialogs>
    </nav>
    <component :is="tab" :settings="settings" :user="user" v-if="tab"></component>
    <convos-dialog-container :dialog="d" :user="user" v-show="d.active()" v-for="d in user.dialogs"></convos-dialog-container>
  </div>
</template>
<script>
module.exports = {
  props: ["settings", "user"],
  data:  function() {
    return {tab: ""};
  },
  events: {
    locationchange: function(hash) {
      this.tab = hash[0] && Convos.tabs[hash[0]] ? "convos-" + hash[0] : "";
      return true;
    }
  }
};
</script>
