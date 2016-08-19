<template>
  <div class="convos-chat">
    <convos-main-menu :user="user"></convos-main-menu>
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
      // Not sure why, but this function is triggered whenever scrolling takes place.
      // this.lastMain is here to prevent a gazillion "active" events.
      if (this.settings.main != this.lastMain && this.settings.main == d.href()) {
        this.lastMain = this.settings.main;
        d.emit("active");
      }

      return this.settings.main == d.href();
    },
    showSettings: function() {
      return this.settings.main.indexOf('#chat') != 0;
    }
  }
};
</script>
