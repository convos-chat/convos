<template>
  <div class="convos-message error">
    <a href="#chat" class="title">convosbot</a>
    <div class="message">
      Do you want desktop notifications for important messages?
      <p>
        <button class="btn waves-effect waves-light" @click="enableNotifications(true)">Yes</button>
        <button class="btn waves-effect waves-light grey" @click="enableNotifications(false)">No</button>
      </p>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"]
};
</script>
