<sidebar-settings>
  <div class="collection">
    <a href={href('settings/connections')} class={activeClass('settings/connections', 'collection-item')}>
      <i class="material-icons">device_hub</i> Edit connections
    </a>
    <a href={href('settings/profile')} class={activeClass('settings/profile', 'collection-item')}>
      <i class="material-icons">account_circle</i> Edit profile
    </a>
    <div class="collection-item split">
      <a href={href('settings/help')} class={activeClass('settings/profile', '')}><i class="material-icons">help</i> Help</a>
      <a href="#logout"><i class="material-icons">power_settings_new</i> Logout</a>
    </div>
  </div>
  <script>
  this.user = opts.user;

  activeClass(href, additional) {
    return additional + (location.hash.indexOf(href) != -1 ? ' active' : '');
  }

  href(url) {
    return '#' + (location.hash.indexOf(url) == -1 ? url : 'chat');
  }
  </script>
</sidebar-settings>
