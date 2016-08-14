<template>
  <div class="convos-header-links">
    <slot></slot>
    <template v-if="!toggle || !settings.sidebar">
      <a v-sidebar.literal="#notifications" data-hint="Show notifications" class="notifications" :class="activeClass('notifications')">
        <i class="material-icons" :class="user.notifications.length ? 'active' : ''">{{user.notifications.length ? "notifications_active" : "notifications_none"}}</i>
        <b class="n-notifications" v-if="user.notifications.length">{{user.notifications.length < 100 ? user.notifications.length : "99+"}}</b>
      </a>
      <a v-sidebar.literal="#profile" data-hint="Edit profile" :class="activeClass('profile')" class="visible-on-med-and-up">
        <i class="material-icons">account_circle</i>
      </a>
      <a v-sidebar.literal="#help" data-hint="Help" :class="activeClass('help')" class="visible-on-med-and-up">
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
