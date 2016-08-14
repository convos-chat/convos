<template>
  <div class="convos-main-menu show-on-large" :class="settings.dialogsVisible ? '' : 'hidden'">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <div class="input-field">
        <input v-model="q" @keydown.enter="search" id="search_field" type="search" autocomplete="off" placeholder="Search...">
        <label for="search_field"><i class="material-icons">search</i></label>
        <!-- i class="material-icons">close</i -->
      </div>
    </header>
    <div class="content">
      <a v-link="d.href()" :data-hint="d.frozen || ''" :class="dialogClass(d, i)" v-for="(i, d) in dialogs()">
        <i class="material-icons">{{d.icon()}}</i> <span class="name">{{d.name}}</span>
        <b class="n-uread" v-if="d.unread">{{d.unread < 100 ? d.unread : "99+"}}</b>
        <span class="on" v-if="d.connection()">{{d.connection().protocol}}-{{d.connection().name}}</span>
        <span class="on" v-else>convos-local</span>
      </a>
      <a v-link.literal="#create-dialog" v-if="user.connections.length" class="simple" :class="activeClass('#create-dialog')">
        <i class="material-icons">add</i> Join dialog...
      </a>

      <div class="divider"></div>
      <a v-link="'#connection/' + c.id" :class="connectionClass(c)" v-for="c in user.connections">
        <i class="material-icons">device_hub</i> {{c.protocol}}-{{c.name}}
        <span class="on">{{c.humanState()}}</span>
      </a>
      <a v-link.literal="#connection" class="simple" :class="activeClass('#connection')">
        <i class="material-icons">add</i> Add connection...
      </a>

      <div class="divider"></div>
      <a v-sidebar.literal="#profile" class="hide-on-large-only simple">
        <i class="material-icons">account_circle</i> Edit profile
      </a>
      <a v-sidebar.literal="#help" :class="activeClass" class="hide-on-large-only simple">
        <i class="material-icons">help</i> Help
      </a>
      <a href="#logout" @click.prevent="logout" class="simple">
        <i class="material-icons">power_settings_new</i> Logout
      </a>
    </div>
  </div>
</template>
<script>
module.exports = {
  props:   ["user"],
  data: function() {
    return {first: null, q: ""};
  },
  methods: {
    connectionClass: function(c) {
      var cn = this.activeClass('#connection/' + c.id);
      cn.frozen = c.state == 'connected' ? false : true;
      return cn;
    },
    dialogClass: function(d, i) {
      if (!i) this.$nextTick(this.overrideHints);
      var cn = this.activeClass(d.href());
      cn.frozen = d.frozen ? true : false;
      return cn;
    },
    dialogs: function() {
      var self = this;
      var q = new RegExp(self.q, "i");
      var dialogs = this.user.dialogs.filter(function(d) {
        return self.q ? d.name.match(q) : true;
      }).sort(function(a, b) {
        return a.name > b.name
      });
      this.first = dialogs[0];
      return dialogs;
    },
    search: function(e) {
      if (e.shiftKey) return this.user.getActiveDialog().emit("focusInput");
      if (this.first && this.q) this.settings.main = d.href();
      this.q = "";
    }
  }
};
</script>
