<sidebar-notifications>
  <span if={!notifications.length}>
    <i class="material-icons">notifications_none</i> No notifications
  </span>
  <a each={notifications}>
    {from}: "{message}" @<span class="ts" title={ts}>{parent.timestring(ts)}</span>
  </a>
  <script>
  this.notifications = [];
  </script>
</sidebar-notifications>
