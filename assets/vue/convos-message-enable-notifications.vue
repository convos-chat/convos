<template>
  <div class="convos-message convos-message-enable-notifications error">
    <a href="#chat" class="title">convosbot</a>
    <div class="message">
      Do you want desktop notifications for important messages?
      <p>
        <button class="btn waves-effect waves-light" @click="enable(true)" :disabled="clicked">Yes</button>
        <button class="btn waves-effect waves-light grey" @click="enable(false)" :disabled="clicked">No</button>
      </p>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"],
  data: function() {
    return {clicked: false};
  },
  methods: {
    enable: function(enable) {
      var activated = enable ? "enabled" : "disabled";
      this.enableNotifications(enable);
      this.clicked = true;
      this.dialog.addMessage({message: "You have now " + activated + ' notifications. This can be changed later in "Edit profile".'});
    }
  }
};
</script>
