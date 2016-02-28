riot.tag2('sidebar-notifications', '<span if="{!notifications.length}"> <i class="material-icons">notifications_none</i> No notifications </span> <a each="{notifications}"> {from}: "{message}" @<span class="ts" title="{ts}">{parent.timestring(ts)}</span> </a>', '', '', function(opts) {
  this.notifications = [];
}, '{ }');
