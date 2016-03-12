riot.tag2('dialog-message-users', '<h5 class="title">Participants ({users.length})</h5> <span if="{!users.length}">No participants. You need to join the dialog first.</span> <a href="{\'#whois:\' + user.name}" onclick="{whois}" each="{user, i in users}"> {user.mode}{user.name}{i + 1 == users.length ? \'.\' : \', \'} </a> <span class="secondary-content"> <a href="#close" onclick="{parent.removeMessage}"><i class="material-icons">close</i></a> </span>', '', '', function(opts) {
  this.users = [];

  this.whois = function(e) {
    opts.dialog.send('/whois ' + e.item.user.name);
  }.bind(this)

  this.on('update', function() {
    var users = opts.dialog.users()
    this.users = Object.keys(users).sort().map(function(name) { return users[name]; });
  });
}, '{ }');
