<template>
  <div class="convos-message notice">
    <a href="#chat" class="title">{{msg.from}}</a>
    <div class="message">
      <template v-if="n > 1">{{nParticipants | capitalize}} participants</template>
      <template v-else>You are the only participant</template>
      in {{dialog.name}}, connected to {{dialog.connection().name}}{{n > 1 ? ":" : "."}}
      <template v-for="p in participants">
        <a href="#whois:{{p.name}}" @click.prevent="whois(p)">{{p.mode}}{{p.name}}</a>{{$index + 2 == n ? " and " : $index + 1 == n ? "" : ", "}}</template>.
      <br>
      <template v-if="dialog.topic">
        The topic is: {{dialog.topic}}
      </template>
      <template v-if="!dialog.topic">
        This dialog has no topic.
      </template>
    </div>
    <span class="secondary-content ts" v-tooltip="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"],
  data: function() {
    var participants = Object.values(this.dialog.participants).sort(function(a, b) {
      if (a.name.toLowerCase() < b.name.toLowerCase()) return -1;
      if (a.name.toLowerCase() > b.name.toLowerCase()) return 1;
      return 0;
    });

    return {
      n: participants.length,
      nParticipants: String.prototype.numberAsString.call(participants.length),
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
