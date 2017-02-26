<template>
  <div class="convos-message notice" :class="classNames()">
    <span class="secondary-content ts" v-tooltip="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
    <a href="#{{msg.from}}" class="title" @click.prevent="insertIntoInput">{{msg.from}}</a>
    <div class="message" v-html="computedMessage"></div>
  </div>
</template>
<script>
module.exports = {
  mixins: [Convos.mixin.message]
};
</script>
