<template>
  <div class="convos-message notice" :class="classNames()">
    <a href="#{{msg.from}}" class="title" @click.prevent="insertIntoInput">{{msg.from}}</a>
    <div class="message">{{{message() | markdown}}}</div>
    <span class="secondary-content ts" v-tooltip="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
  </div>
</template>
<script>
module.exports = {
  mixins: [Convos.mixin.message]
};
</script>
