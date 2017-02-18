<template>
  <div class="convos-main-menu show-on-large" :class="settings.mainMenuVisible ? '' : 'hidden'">
    <div class="content">
      <div :class="dialogClass(d, $index)" v-for="d in dialogs">
        <a v-link="d.href()" v-tooltip="d.frozen">
          <i class="material-icons">{{d.icon()}}</i> <span class="name">{{d.dialog_id ? d.name : d.connection_id}}</span>
          <span class="n-unread badge" v-if="d.unread && !d.active" v-tooltip="d.unread + ' unread messages'">{{d.unread < 50 ? d.unread : "50+"}}</span>
          <span class="on" v-if="showConnectionInfo(d)">{{d.connection().protocol}}-{{d.connection().name}}</span>
        </a>
        <span class="close badge" @click.prevent="close(d)" v-if="d.dialog_id">&times;</span>
      </div>
      <div class="divider"></div>
      <div class="link" :class="activeClass('#create-dialog')">
        <a v-link="'#create-dialog/' + user.activeDialog('connection_id')" v-if="user.connections.length" class="simple">
          <i class="material-icons">add</i> Join dialog...
        </a>
      </div>
      <div class="link" :class="activeClass('#connection')">
        <a v-link.literal="#connection" class="simple">
          <i class="material-icons">add</i> Add connection...
        </a>
      </div>
      <div class="link" :class="activeClass('#profile')">
        <a v-link.literal="#profile" class="simple">
          <i class="material-icons">account_circle</i> Edit profile
        </a>
      </div>
      <div class="link" :class="activeClass('#help')">
        <a v-link.literal="#help" class="simple">
          <i class="material-icons">help</i> Help
        </a>
      </div>
      <div class="link">
        <a v-link.literal="/api/user/logout" class="simple">
          <i class="material-icons">power_settings_new</i> Logout
        </a>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["dialogFilter", "user"],
  computed: {
    dialogs: function() {
      var di = function(a, b) {
        return (b.dialog_id.length ? 1 : 0) - (a.dialog_id.length ? 1 : 0);
      };

      if (this.dialogFilter) {
        var re = new RegExp(RegExp.escape(this.dialogFilter), 'i');
        return this.user.dialogs.filter(function(d) {
          return d.name.match(re);
        }).sort(function(a, b) {
          return a.name.length - b.name.length;
        });
      }
      else if (this.settings.sortDialogsBy == "lastRead") {
        var nTop = localStorage.getItem("lastReadnTop") || 3; // EXPERIMENTAL value
        var dialogs = this.user.dialogs.sort(function(a, b) {
          return (b.active || false) - (a.active || false) || di(a, b) || b.lastRead - a.lastRead;
        });
        return dialogs.slice(0, nTop).concat(dialogs.slice(nTop).sort(function(a, b) {
          return di(a, b)
              || (b.unread ? 1 : 0) - (a.unread ? 1 : 0)
              || b.lastActive - a.lastActive
              || b.lastRead - a.lastRead
              || a.name.toLowerCase().localeCompare(b.name.toLowerCase());
        }));
      }
      else {
        return this.user.dialogs.sort(function(a, b) {
          var ah = a.name.toLowerCase().replace(/^\W+/, '');
          var bh = b.name.toLowerCase().replace(/^\W+/, '');
          return di(a, b) || ah.localeCompare(bh);
        });
      }
    }
  },
  events: {
    gotoDialog: function() {
      this.settings.main = this.dialogs.length ? this.dialogs[0].href() : "#create-dialog/" + this.user.activeDialog('connection_id') + "/" + this.dialogFilter;
    }
  },
  methods: {
    close: function(d) {
      this.send('/close ' + d.name, d);
    },
    dialogClass: function(d, i) {
      var cn = this.activeClass(d.href());
      cn.link = true;
      cn.dialog = d.dialog_id ? true : false;
      if (this.dialogFilter) cn.active = i ? true : false;
      cn.frozen = d.frozen ? true : false;
      return cn;
    },
    search: function(e) {
      if (!this.dialogFilter.length || e.shiftKey) return;
      this.settings.main = this.dialogs.length ? this.dialogs[0].href() : "#create-dialog/" + user.activeDialog('connection_id') + "/" + this.dialogFilter;
      this.dialogFilter = "";
    },
    showConnectionInfo: function(d) {
      return d.dialog_id && this.user.connections.length > 1;
    }
  }
};
</script>
