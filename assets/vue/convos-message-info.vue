<template>
  <div class="convos-dialog-info convos-message notice">
    <a href="#chat" class="title">{{msg.from}}</a>
    <div class="message">
      <span>
        <template v-if="dialog.participants.length">{{nParticipants | capitalize}} participants</template>
        <template v-else>You are the only participant</template>
        in {{dialog.name}}, connected to {{dialog.connection().name}}.
        <template v-for="p in participants">
          <a href="#whois:{{p.name}}" @click.prevent="whois(p)">{{p.mode}}{{p.name}}</a>{{$index + 1 == participants.length ? "." : ", "}}
        </template>
        <template v-if="dialog.topic">
          The topic is: {{dialog.topic}}
        </template>
        <template v-if="!dialog.topic">
          This dialog has no topic.
        </template>
      </span>
    </div>
    <span class="secondary-content ts" :data-hint="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"],
  data: function() {
    var participants = Object.values(this.dialog.participants).filter(function(p) {
      return p.online;
    }).sort(function(a, b) {
      if (a.name.toLowerCase() < b.name.toLowerCase()) return -1;
      if (a.name.toLowerCase() > b.name.toLowerCase()) return 1;
      return 0;
    });

    return {
      nParticipants: String.prototype.numberAsString.call(participants.length + 1),
      participants: participants
    };
  },
  methods: {
    whois: function(p) {
      this.dialog.connection().send("/whois " + p.name);
    }
  }
};
</script>
