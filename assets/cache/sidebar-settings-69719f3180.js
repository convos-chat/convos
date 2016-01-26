riot.tag2('sidebar-settings', '<div class="collection"> <a href="#connection-edit" title="{this.state()}" onclick="{parent.editConnection}" class="collection-item" each="{user.connections()}"> <i class="{parent.connectionClasses(this)}">device_hub</i> {this.protocol()} {this.name()} </a> <a href="#connection-add" onclick="{editConnection}" class="collection-item"> <i class="material-icons">device_hub</i> Add connection... </a> <a href="#profile" onclick="{editProfile}" class="collection-item"> <i class="material-icons">account_circle</i> Edit profile </a> <a href="#logout" class="collection-item"> <i class="material-icons">power_settings_new</i> Logout </a> </div>', '', '', function(opts) {

  mixin.modal(this);

  this.user = opts.user;

  this.connectionClasses = function(c) {
    return 'material-icons state-' + c.state();
  }.bind(this)

  this.editConnection = function(e) {
    var opts = {connection: e.item, user: this.user};
    if (!e.item) opts.next = 'conversation-add';
    this.openModal(e.currentTarget.href.split('#')[1], opts);
  }.bind(this)

  this.editProfile = function(e) {
    this.openModal('user-profile', {user: this.user});
  }.bind(this)

}, '{ }');
