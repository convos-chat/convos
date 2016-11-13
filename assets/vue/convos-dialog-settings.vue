<template>
  <div class="content">
    <div class="row">
      <div class="col s12">
        <h5>About {{dialog.name}}</h5>
        <p v-if="!dialog.is_private">{{{dialog.topic || 'No topic is set.' | markdown markdownOptions}}}</p>
        <p v-if="dialog.is_private">This is a private conversation.</p>
      </div>
    </div>
    <div class="menu-item">
      <a href="#close" @click.prevent="send('/close')">
        <i class="material-icons right">close</i>
        {{dialog.is_private ? 'Close conversation' : 'Part channel'}}
      </a>
    </div>
    <div class="menu-item" v-if="settings.share_dialog">
      <a :href="shareUrl()" target="_blank">
        <i class="material-icons right">share</i>
        Share conversation
      </a>
    </div>
    <div class="row">
      <div class="col s12">
        <h5>Participants ({{participants.length}})</h5>
      </div>
    </div>
    <div class="menu-item" v-for="p in participants">
      <span class="right">
        {{modes[p.mode] || p.mode}}
        <a href="#info" @click.prevent="send('/whois ' + p.name)" class="waves-effect waves-light"><i class="material-icons">info</i></a>
      </span>
      <a href="#chat:{{p.name}}" @click.prevent="send('/query ' + p.name)">{{p.name}}</a>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "user"],
  data: function() {
    return {
      markdownOptions: {escape: true, links: true},
      modes: {
        '%': '+h',
        '&': '+a',
        '+': '+v',
        '@': '+o',
        '~': '+q'
      }
    };
  },
  computed: {
    participants: function() {
      if (!this.dialog) return [];
      return Object.keys(this.dialog.participants)
        .sort(function(a, b) { return a.toLowerCase().localeCompare(b.toLowerCase()); })
        .map(function(k) { return this.dialog.participants[k] || {name: k}; }.bind(this));
    }
  },
  methods: {
    shareUrl: function() {
      var dialog = this.dialog;
      return ['', 'api', 'connection', dialog.connection_id, 'dialog', dialog.dialog_id, 'share']
        .map(function(p) { return encodeURIComponent(p) })
        .join('/');
    }
  }
};
</script>
