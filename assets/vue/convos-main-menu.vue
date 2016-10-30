<template>
  <div class="convos-main-menu show-on-large" :class="settings.dialogsVisible ? '' : 'hidden'">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <div class="input-field">
        <input v-model="q" @keydown.enter="search" id="goto_anything" type="search" autocomplete="off" placeholder="Search...">
        <label for="goto_anything"><i class="material-icons">search</i></label>
      </div>
    </header>
    <div class="content">
      <a v-link="d.href()" v-tooltip="d.frozen" :class="dialogClass(d)" v-for="d in dialogs">
        <i class="material-icons">{{d.icon()}}</i> <span class="name">{{d.name}}</span>
        <b class="n-uread" v-if="d.unread">{{d.unread < 100 ? d.unread : "99+"}}</b>
        <span class="on" v-if="d.connection()">{{d.connection().protocol}}-{{d.connection().name}}</span>
        <span class="on" v-else>convos-local</span>
      </a>
      <div class="divider"></div>
      <a v-sidebar.literal="#profile" class="simple">
        <i class="material-icons">account_circle</i> Edit profile
      </a>
      <a v-sidebar.literal="#help" :class="activeClass" class="simple">
        <i class="material-icons">help</i> Help
      </a>
      <a v-link.literal="/api/user/logout" class="simple">
        <i class="material-icons">power_settings_new</i> Logout
      </a>
      <a v-link.literal="#create-dialog" v-if="user.connections.length" class="btn-floating waves-effect waves-light"><i class="material-icons">add</i></a>
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
      var re = this.q ? new RegExp(RegExp.escape(this.q), 'i') : new RegExp('.');
      var sortBy;

      var di = function(a, b) {
        return (b.dialog_id.length ? 1 : 0) - (a.dialog_id.length ? 1 : 0);
      };

      if (this.settings.sortDialogsBy == "lastRead") {
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

      return this.user.dialogs.filter(function(d) { return d.name.match(re) }).sort(sortBy);
    }
  },
  methods: {
    dialogClass: function(d) {
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
