<template>
  <div class="convos-main-menu show-on-large" :class="settings.mainMenuVisible ? '' : 'hidden'">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <div class="input-field">
        <input v-model="q" @keydown.enter="search" id="goto_anything" type="search" autocomplete="off" placeholder="Search...">
        <label for="goto_anything"><i class="material-icons">search</i></label>
      </div>
    </header>
    <div class="content">
      <a v-link="d.href()" v-tooltip="d.frozen" :class="dialogClass(d, $index)" v-for="d in dialogs">
        <i class="material-icons">{{d.icon()}}</i> <span class="name">{{d.name}}</span>
        <b class="n-uread" v-if="d.unread">{{d.unread < 100 ? d.unread : "99+"}}</b>
        <span class="on" v-if="d.connection()">{{d.connection().protocol}}-{{d.connection().name}}</span>
        <span class="on" v-else>convos-local</span>
      </a>
      <div class="divider"></div>
      <a v-link.literal="#create-dialog" v-if="user.connections.length" class="simple" :class="activeClass('#create-dialog')">
        <i class="material-icons">add</i> Join dialog...
      </a>
      <a v-link.literal="#connection" class="simple" :class="activeClass('#connection')">
        <i class="material-icons">add</i> Add connection...
      </a>
      <a v-sidebar.literal="#profile" class="simple">
        <i class="material-icons">account_circle</i> Edit profile
      </a>
      <a v-sidebar.literal="#help" :class="activeClass" class="simple">
        <i class="material-icons">help</i> Help
      </a>
      <a v-link.literal="/api/user/logout" class="simple">
        <i class="material-icons">power_settings_new</i> Logout
      </a>
    </div>
  </div>
</template>
<script>
module.exports = {
  props:   ["user"],
  data: function() {
    return {q: ""};
  },
  computed: {
    dialogs: function() {
      var dialogs = this.user.dialogs;
      var sortBy;

      var di = function(a, b) {
        return (b.dialog_id.length ? 1 : 0) - (a.dialog_id.length ? 1 : 0);
      };

      if (this.q) {
        var re = new RegExp(RegExp.escape(this.q), 'i');
        dialogs = dialogs.filter(function(d) { return d.name.match(re) });
        sortBy = function(a, b) {
          return a.name.length - b.name.length;
        };
      }
      else if (this.settings.sortDialogsBy == "lastRead") {
        sortBy = function(a, b) {
          return b.active - a.active || di(a, b) || b.lastRead - a.lastRead;
        };
      }
      else {
        sortBy = function(a, b) {
          var ah = a.name.toLowerCase().replace(/^\W+/, '');
          var bh = b.name.toLowerCase().replace(/^\W+/, '');
          return di(a, b) || ah < bh ? -1 : ah > bh ? 1 : 0;
        };
      }

      return dialogs.sort(sortBy);
    }
  },
  methods: {
    dialogClass: function(d, i) {
      if (this.q) return i ? "" : "active";
      var cn = this.activeClass(d.href());
      cn.frozen = d.frozen ? true : false;
      return cn;
    },
    search: function(e) {
      if (!this.q.length || e.shiftKey) return;
      this.settings.main = this.dialogs.length ? this.dialogs[0].href() : "#create-dialog/" + this.q;
      this.q = "";
    }
  }
};
</script>
