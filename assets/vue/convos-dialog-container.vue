<template>
  <div class="convos-dialog-container">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <h2 v-tooltip="dialog.topic || 'No topic is set.'">{{user.ws.is('open') ? dialog.name || 'Convos' : 'No internet connection?'}}</h2>
      <convos-header-links :toggle="true" :user="user"></convos-header-links>
    </header>
    <main>
      <component
        :is="'convos-message-' + msg.type"
        :dialog="dialog"
        :msg="msg"
        :user="user"
        v-if="msg.type"
        v-for="msg in dialog.messages"></component>
    </main>
    <convos-input :dialog="dialog" :user="user"></convos-input>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "user"],
  mixins: [Convos.mixin.messages]
};
</script>
