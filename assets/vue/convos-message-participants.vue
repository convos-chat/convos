<template>
  <div class="convos-message notice">
    <span class="secondary-content ts" v-tooltip="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
    <a href="#chat" class="title">{{msg.from}}</a>
    <div class="message">
      <template v-if="n > 1">{{nParticipants | capitalize}} participants</template>
      <template v-else>You are the only participant</template>
      in {{dialog.name}}, connected to {{dialog.connection().name}}{{n > 1 ? ":" : "."}}
      <template v-for="p in participants">
        <a href="#query:{{p.name}}" @click.prevent="query(p)">{{p.mode}}{{p.name}}</a>{{$index + 2 == n ? " and " : $index + 1 == n ? "" : ", "}}</template>.
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"],
  data: function() {
    var participants = this.dialog.participants()
      .filter(function(p) { return p.online; })
      .sort(function(a, b) {
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
    query: function(p) {
      this.dialog.connection().send("/query " + p.name);
    }
  }
};
</script>
