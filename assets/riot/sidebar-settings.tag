<sidebar-settings>
  <div class="collection">
    <a href="#new-connection" class="collection-item">
      <i class="material-icons">device_hub</i> New connection
    </a>
    <a href="#profile" class="collection-item">
      <i class="material-icons">account_circle</i> Edit profile
    </a>
    <div class="collection-item split">
      <a href="#logout"><i class="material-icons">power_settings_new</i> Logout</a>
      <a href="#help"><i class="material-icons">help</i> Help</a>
    </div>
  </div>
  <script>
  this.user = opts.user;

  connectionClasses(c) {
    return 'material-icons state-' + c.state();
  }
  </script>
</sidebar-settings>
