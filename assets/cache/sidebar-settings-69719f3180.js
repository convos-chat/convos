riot.tag2('sidebar-settings', '<div class="collection"> <a href="#new-connection" class="collection-item"> <i class="material-icons">device_hub</i> New connection </a> <a href="#profile" class="collection-item"> <i class="material-icons">account_circle</i> Edit profile </a> <div class="collection-item split"> <a href="#logout"><i class="material-icons">power_settings_new</i> Logout</a> <a href="#help"><i class="material-icons">help</i> Help</a> </div> </div>', '', '', function(opts) {
  this.user = opts.user;

  this.connectionClasses = function(c) {
    return 'material-icons state-' + c.state();
  }.bind(this)
});
