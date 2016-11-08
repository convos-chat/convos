<template>
  <div class="convos-header-links">
    <slot></slot>
    <template v-if="!toggle || !settings.sidebar">
      <a v-sidebar.literal="#dialog-settings" v-tooltip.literal="Dialog settings" :class="activeClass('dialog-settings')">
        <i class="material-icons">info</i>
      </a>
      <a v-sidebar.literal="#notifications" v-tooltip.literal="Show notifications" class="notifications" :class="activeClass('notifications')">
        <i class="material-icons" :class="user.unread ? 'active' : ''">{{user.unread ? "notifications_active" : "notifications_none"}}</i>
        <b class="n-notifications" v-if="user.unread">{{user.unread < 100 ? user.unread : "99+"}}</b>
      </a>
    </template>
  </div>
</template>
<script>
module.exports = {
  props: ["toggle", "user"]
};
</script>
