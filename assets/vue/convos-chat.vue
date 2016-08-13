<template>
  <div class="convos-chat">
    <convos-dialogs :user="user"></convos-dialogs>
    <convos-dialog-container :dialog="d" :user="user" v-show="showDialogContainer(d)" v-for="d in user.dialogs"></convos-dialog-container>
    <convos-settings :user="user" v-show="showSettings()"></convos-settings>
    <component :is="'convos-' + settings.sidebar" :user="user" v-if="settings.sidebar"></component>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  methods: {
    showDialogContainer: function(d) {
      var visible = this.settings.main == d.href();
      if (visible) {
        d.unread = 0;
        d.emit("visible");
      }
      return visible;
    },
    showSettings: function() {
      return this.settings.main.indexOf('chat') == -1;
    }
  }
};
</script>
