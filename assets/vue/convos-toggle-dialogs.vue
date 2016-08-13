<template>
  <a href="#dialogs" @click.prevent="toggleDialogs" :class="classNames()"><i class="material-icons">dehaze</i></a>
</template>
<script>
module.exports = {
  methods: {
    classNames: function() {
      var cn = {"toggle-dialogs": true};
      if (this.settings.dialogsVisible) cn.active = true;
      return cn;
    },
    toggleDialogs: function() {
      if (!Convos.settings.dialogsVisible) Convos.settings.sidebar = "";
      Convos.settings.dialogsVisible = !Convos.settings.dialogsVisible;
    }
  }
};
</script>
