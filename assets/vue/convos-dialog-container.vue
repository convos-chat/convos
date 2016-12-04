<template>
  <div class="convos-dialog-container">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <h2>{{user.ws.is('open') ? dialog.name || 'Convos' : 'No internet connection?'}}</h2>
      <convos-header-links :toggle="true" :user="user"></convos-header-links>
    </header>
    <main class="scroll-element" v-el:main>
      <component
        :is="'convos-message-' + msg.type"
        :dialog="dialog"
        :msg="msg"
        :user="user"
        v-if="msg.type"
        v-for="msg in dialog.messages"></component>
    </main>
    <convos-input :dialog="dialog" :user="user" @resized="draw" v-el:input></convos-input>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "user"],
  mixins: [Convos.mixin.messages],
  methods: {
    draw: function(e) {
      this.$els.main.style.bottom = this.$els.input.offsetHeight + "px";
      this.keepScrollPos();
    }
  }
};
</script>
