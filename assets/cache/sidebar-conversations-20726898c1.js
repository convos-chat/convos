riot.tag2('sidebar-conversations', '<div class="collection"> <a href="{\'#\' + c.url()}" class="{parent.conversationClass(c)}" each="{c, i in user.conversations()}"> <i class="material-icons">{c.icon()}</i> {c.name()} </a> <a href="#addConversation" onclick="{addConversation}" class="collection-item"> <i class="material-icons">add_circle</i> Create conversation... </a> </div>', '', '', function(opts) {

  mixin.modal(this);

  this.user = opts.user;

  this.addConversation = function(e) {
    if (this.user.connections().length) {
      this.openModal('conversation-add', {user: this.user});
    }
    else {
      this.openModal('connection-add', {first: true, next: 'conversation-add', user: this.user});
    }
  }.bind(this)

  this.conversationClass = function(c) {
    return c == this.parent.conversation ? 'collection-item active' : 'collection-item';
  }.bind(this)

}, '{ }');
