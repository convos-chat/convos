<sidenav-conversations>
  <div class="collection">
    <a each={conversations} href={url()} class={parent.conversationClass(i)}>
      <i class="material-icons">{icon()}</i> {name()}
    </a>
    <a href="#addConversation" onclick={addConversation} class="collection-item">
      <i class="material-icons">add_circle</i> Create conversation...
    </a>
  </div>
  <script>

  mixin.modal(this);

  this.user = opts.user;
  this.conversations = [];

  addConversation(e) {
    this.user.connections(function(err, connections) {
      if (connections.length) {
        this.openModal('add-conversation', {connections: connections, user: this.user});
      }
      else {
        this.openModal('add-connection', {first: true, next: 'add-conversation', user: this.user});
      }
    }.bind(this));
  }

  conversationClass(i) {
    return i == this.parent.activeConversation ? 'collection-item active' : 'collection-item';
  }

  this.on('mount', function() {
    this.user.conversations(function(err, conversations) { this.conversations = conversations; this.update(); }.bind(this));
    this.user.on('conversation', function(conversation) { this.conversations.unshift(conversation); this.update(); }.bind(this));
  });

  </script>
</sidenav-conversations>
