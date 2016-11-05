<template>
  <a href="#main-menu" @click.prevent="toggleMainMenu" :class="classNames()"><i class="material-icons">dehaze</i></a>
</template>
<script>
module.exports = {
  methods: {
    classNames: function() {
      var cn = {"toggle-main-menu": true};
      if (this.settings.mainMenuVisible) cn.active = true;
      return cn;
    },
    toggleMainMenu: function() {
      if (!this.settings.mainMenuVisible) this.settings.sidebar = "";
      this.settings.mainMenuVisible = !this.settings.mainMenuVisible;
    }
  }
};
</script>
