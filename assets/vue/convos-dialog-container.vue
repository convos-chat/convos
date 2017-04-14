<template>
  <div class="convos-dialog-container" :class="dialog.active ? 'active' : ''">
    <main class="scroll-element" v-el:main>
      <component
        :is="'convos-message-' + msg.type"
        :dialog="dialog"
        :msg="msg"
        :user="user"
        v-ref:messages
        v-for="msg in dialog.messages"></component>
    </main>
    <convos-input :dialog="dialog" :user="user" @resized="resized" v-el:input></convos-input>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "user"],
  mixins: [Convos.mixin.messages],
  methods: {
    resized: function(e) {
      this.$els.main.style.bottom = this.$els.input.offsetHeight + "px";
    }
  }
};
</script>
