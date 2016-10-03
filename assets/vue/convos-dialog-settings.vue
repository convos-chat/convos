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
      <div class="row" v-if="settings.share_dialog">
        <div class="col s12 li-link">
          <a :href="shareUrl()" target="_blank">
            <i class="material-icons">share</i>
            Share conversation
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
      return Object.keys(this.dialog.participants)
        .sort(function(a, b) { return a.toLowerCase().localeCompare(b.toLowerCase()); })
        .map(function(k) { return this.dialog.participants[k] || {name: k}; }.bind(this));
    }
  },
  methods: {
    closeTooltip: function() {
      return this.dialog.is_private ? 'Close conversation' : 'Part channel';
    },
    shareUrl: function() {
      var dialog = this.dialog;
      return ['', 'api', 'connection', dialog.connection_id, 'dialog', dialog.dialog_id, 'share']
        .map(function(p) { return encodeURIComponent(p) })
        .join('/');
    }
  }
};
</script>
