<template>
  <div class="convos-dialog-settings is-sidebar">
    <header><convos-header-links :user="user"></convos-header-links></header>
    <div class="content" v-if="!dialog">
      <div class="row">
        <div class="col s12">
          <h5>About Convos</h5>
          <convos-resources></convos-resources>
        </div>
      </div>
    </div>
    <div class="content" v-if="dialog">
      <div class="row">
        <div class="col s12">
          <h5>About {{dialog.name}}</h5>
          <p v-if="!dialog.is_private">{{{dialog ? dialog.topic || 'No topic is set.' : 'No active dialog.' | markdown mOpts}}}</p>
          <p v-if="dialog.is_private">You're in a private conversation.</p>
        </div>
      </div>
      <div class="row">
        <div class="col s12 li-link">
          <a href="#close" @click.prevent="send('/close')" v-if="dialog">
            <i class="material-icons">close</i>
            {{closeTooltip()}}
          </a>
        </div>
      </div>
      <div class="row">
        <div class="col s12">
          <h5>Participants ({{participants.length}})</h5>
        </div>
      </div>
      <div class="row participant" v-for="p in participants">
        <div class="col s12">
          <span class="secondary-content ts">
            {{modes[p.mode] || p.mode}}
            <a href="#info" @click.prevent="send('/whois ' + p.name)" class="waves-effect waves-light"><i class="material-icons">info</i></a>
          </span>
          <a href="#chat:{{p.name}}" @click.prevent="send('/query ' + p.name)">{{p.name}}</a>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {mOpts: {escape: true, links: true}, modes: {'@': '+o', '+': '+v'}};
  },
  computed: {
    dialog: function() {
      return this.user.getActiveDialog();
    },
    participants: function() {
      if (!this.dialog) return [];

      var nick = this.dialog.connection().nick();
      var list = this.dialog.name == nick ? [nick]
               : this.dialog.is_private ? [this.dialog.name, nick]
               : Object.keys(this.dialog.participants);

      return list
        .sort(function(a, b) { return a.toLowerCase().localeCompare(b.toLowerCase()); })
        .map(function(k) { return this.dialog.participants[k] || {name: k}; }.bind(this));
    }
  },
  methods: {
    closeTooltip: function() {
      return this.dialog.is_private ? 'Close conversation' : 'Part channel';
    }
  }
};
</script>
