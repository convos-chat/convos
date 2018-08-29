<template>
  <div class="convos-chat">
    <header>
      <a href="#main-menu" @click.prevent="toggleMainMenu" class="toggle-main-menu" :class="settings.mainMenuVisible ? 'active' : ''"><i class="material-icons">dehaze</i></a>
      <div class="input-field">
        <input v-model="searchQuery" @keydown.enter="search" id="goto_anything" type="search" autocomplete="off" placeholder="Search...">
        <label for="goto_anything"><i class="material-icons">search</i></label>
      </div>
      <h2>{{header()}}</h2>
      <div class="convos-header-links">
        <a v-sidebar.literal="#sidebar-info" v-tooltip.literal="Dialog settings" :class="activeClass('sidebar-info')">
          <i class="material-icons">info</i>
        </a>
        <a v-sidebar.literal="#notifications" v-tooltip.literal="Show notifications" class="notifications" :class="activeClass('notifications')">
          <i class="material-icons" :class="user.unread ? 'active' : ''">{{user.unread ? "notifications_active" : "notifications_none"}}</i>
          <b class="n-notifications" v-if="user.unread">{{user.unread < 100 ? user.unread : "99+"}}</b>
        </a>
      </div>
    </header>
    <convos-dialog-container :dialog="user.activeDialog()" :user="user" v-if="user.activeDialog()"></convos-dialog-container>
    <convos-settings :error="error" :user="user" v-if="show == 'settings'"></convos-settings>
    <component :is="'convos-' + settings.sidebar" :user="user" v-if="settings.sidebar"></component>
    <convos-main-menu :user="user" :dialog-filter.sync="searchQuery" v-ref:mainmenu></convos-main-menu>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {searchQuery: "", show: "", error: {}};
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
        if (dialog.href() == main || (i == 0 && !main)) {
          Convos.settings.main = dialog.href(); // in case not already set
          dialog.update({active: true});
          this.show = "dialog";
          this.error = {};
        }
        else if (dialog.active !== undefined) {
          dialog.update({active: false});
        }
      }
    },
    header: function() {
      var dialog = this.user.activeDialog();
      return dialog && dialog.name ? dialog.name : "Convos";
    },
    search: function(e) {
      if (!this.searchQuery.length || e.shiftKey) return;
      this.$refs.mainmenu.$emit("gotoDialog");
      this.searchQuery = "";
    },
    toggleMainMenu: function() {
      this.settings.sidebar = "";
      this.settings.mainMenuVisible = !this.settings.mainMenuVisible;
    }
  },
  ready: function() {
    this.calculateMainArea();
  }
};
</script>
