<template>
  <div class="convos-chat">
    <convos-main-menu :user="user"></convos-main-menu>
    <convos-dialog-container :dialog="d" :user="user" v-show="d.active" v-for="d in user.dialogs"></convos-dialog-container>
    <convos-settings :error="error" :user="user" v-if="show == 'settings'"></convos-settings>
    <component :is="'convos-' + settings.sidebar" :user="user" v-if="settings.sidebar"></component>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {show: "", error: {}};
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

      this.show = "settings";
      this.error = {message: "Could not find dialog " + main + "."};

      for (i = 0; i < this.user.dialogs.length; i++) {
        var dialog = this.user.dialogs[i];
        if (dialog.href() == main) {
          dialog.active = true;
          this.show = "dialog";
        }
        else if (dialog.active !== undefined) {
          dialog.active = false;
        }
      }
    }
  },
  ready: function() {
    this.calculateMainArea();
  }
};
</script>
