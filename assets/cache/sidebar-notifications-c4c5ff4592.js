riot.tag2('sidebar-notifications', '<ul class="collection"> <li class="collection-item" each="{notifications}"> {from}: "{message}" @<span class="ts" title="{ts}">{parent.timestring(ts)}</span> </li> <li class="collection-item" if="{!notifications.length}"> <i class="material-icons">notifications_none</i> No notifications </li> </ul>', '', '', function(opts) {
  this.notifications = [];
}, '{ }');
