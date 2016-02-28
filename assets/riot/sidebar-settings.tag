<sidebar-settings>
  <a href={href('settings/new-dialog')} class={activeClass('settings/new-dialog')} title="Create dialog" data-position="top">
    <i class="material-icons">group_add</i>
  </a>
  <a href={href('settings/connections')} class={activeClass('settings/connections')} title="Edit connections" data-position="top">
    <i class="material-icons">device_hub</i>
  </a>
  <a href={href('settings/profile')} class={activeClass('settings/profile')} title="Edit profile" data-position="top">
    <i class="material-icons">account_circle</i>
  </a>
  <a href={href('settings/help')} class={activeClass('settings/help')} title="Help" data-position="top">
    <i class="material-icons">help</i>
  </a>
  <a href="#logout" class="tooltipped" title="Logout" data-position="top">
    <i class="material-icons">power_settings_new</i>
  </a>
  <script>
  this.user = opts.user;

  activeClass(href) {
    return (location.hash.indexOf(href) != -1 ? 'tooltipped active' : 'tooltipped');
  }

  href(url) {
    return '#' + (location.hash.indexOf(url) == -1 ? url : 'chat');
  }
  </script>
</sidebar-settings>
