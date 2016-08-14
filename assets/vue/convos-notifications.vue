<template>
  <div class="convos-notifications is-sidebar">
    <header><convos-header-links :user="user"></convos-header-links></header>
    <div class="content">
      <div class="row" v-if="!user.notifications.length">
        <h5 class="center">No notifications.</h5>
      </div>
      <div class="row notification" @click="gotoMessage(msg)" v-for="msg in user.notifications">
        <div class="col s12">
          <span class="secondary-content ts" v-tooltip="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
          <h5>{{msg.from}} in {{msg.dialog_id}}</h5>
          <div class="message">{{msg.message}}</div>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  methods: {
    gotoMessage: function(msg) {
      alert('TODO');
    }
  }
};
</script>
