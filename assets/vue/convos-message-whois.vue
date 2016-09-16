<template>
  <div class="convos-message notice">
    <span class="secondary-content ts" v-tooltip="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
    <a href="#chat" class="title">{{msg.from}}</a>
    <div class="message">
      <a href="#chat:{{msg.nick}}" @click.prevent="send('/query ' + msg.nick)" v-tooltip="msg.name || 'No name?'">{{msg.nick}}</a>
      (<abbr v-tooltip="msg.server + ' - ' + msg.server_info">{{msg.user.replace(/^\~/, '')}}@{{msg.host}}</abbr>)
      <template v-if="msg.idle_for">has been idle for {{msg.idle_for | seconds}}{{channels.length ? " in" : "."}}</template>
      <template v-if="!msg.idle_for && channels.length">is active in</template>
      <template v-if="!msg.idle_for && !channels.length">is not active in any channels.</template>
      <template v-for="name in channels">
        <a href="#join:{{name}}" @click.prevent="send('/join ' + name)">{{name}}</a>{{$index + 2 == channels.length ? " and " : $index + 1 == channels.length ? "." : ", "}}
      </template>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"],
  data: function() {
    return {channels: Object.keys(this.msg.channels)};
  }
};
</script>
