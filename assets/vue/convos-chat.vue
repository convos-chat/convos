<template>
  <div class="convos-chat">
    <convos-main-menu :user="user"></convos-main-menu>
    <convos-dialog-container keep-alive :dialog="dialog" :user="user" class="active" v-if="dialog"></convos-dialog-container>
    <convos-settings :error="error" :user="user" v-if="!dialog"></convos-settings>
    <component :is="'convos-' + settings.sidebar" :user="user" v-if="settings.sidebar"></component>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {dialog: null, error: {}};
  },
  watch: {
    "settings.main": function(v, o) {
      this.calculateMainArea();
    }
  },
  methods: {
    calculateMainArea: function() {
      var main = Convos.settings.main;
      var i;

      this.dialog = null;
      if (main.length && main.indexOf("#chat") != 0) return;

      for (i = 0; i < this.user.dialogs.length; i++) {
        var d = this.user.dialogs[i];
        if (d.href() != main) continue
        this.dialog = d.emit("active");
        break;
      }

      if (!this.dialog) {
        this.error = {
          message: "Could not find dialog " + main + "."
        };
      }
    }
  },
  ready: function() {
    this.calculateMainArea();
  }
};
</script>
