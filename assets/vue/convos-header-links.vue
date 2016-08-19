<template>
  <div class="convos-header-links">
    <slot></slot>
    <template v-if="!toggle || !settings.sidebar">
      <a v-sidebar.literal="#notifications" v-tooltip.literal="Show notifications" class="notifications" :class="activeClass('notifications')">
        <i class="material-icons" :class="user.unread ? 'active' : ''">{{user.unread ? "notifications_active" : "notifications_none"}}</i>
        <b class="n-notifications" v-if="user.unread">{{user.unread < 100 ? user.unread : "99+"}}</b>
      </a>
      <a v-sidebar.literal="#profile" v-tooltip.literal="Edit profile" :class="activeClass('profile')" class="visible-on-med-and-up">
        <i class="material-icons">account_circle</i>
      </a>
      <a v-sidebar.literal="#help" v-tooltip.literal="Help" :class="activeClass('help')" class="visible-on-med-and-up">
        <i class="material-icons">help</i>
      </a>
    </template>
  </div>
</template>
<script>
module.exports = {
  props: ["toggle", "user"]
};
</script>
