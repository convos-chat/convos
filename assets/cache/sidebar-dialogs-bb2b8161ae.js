riot.tag2('sidebar-dialogs', '<a href="{d.href()}" onclick="{setCurrentDialog}" class="{parent.dialogClass(d)}" each="{d, i in user.dialogs()}"> <i class="material-icons">{d.icon()}</i> <span class="name">{d.name()}</span> <span class="on">{d.connection().protocol()}-{d.connection().name()}</span> </a> <a href="#settings/connections" class="{parent.dialogClass(c)}" each="{c, i in user.connections()}"> <i class="material-icons">device_hub</i> {c.protocol()}-{c.name()} <span class="on">{c.humanState()}</span> </a>', '', '', function(opts) {
  this.user = opts.user;

  this.setCurrentDialog = function(e) {
    this.user.currentDialog(e.item.d);
    riot.update();
  }.bind(this)

  this.dialogClass = function(d) {
    return d == this.user.currentDialog() ? 'active' : '';
  }.bind(this)

  this.activeClass = function(href, additional) {
    return additional + (location.hash.indexOf(href) != -1 ? ' active' : '');
  }.bind(this)

  this.href = function(url) {
    return '#' + (location.hash.indexOf(url) == -1 ? url : 'chat');
  }.bind(this)
}, '{ }');
