<sidenav-conversations>
  <div class="collection">
    <sidenav-link each={c, i in conversations} active={i == parent.parent.activeConversation} icon={c.icon()} href={c.url()} new={i}>{c.name()}</sidenav-link>
    <a href="#add:conversation" class="collection-item" onclick={joinConversation}>
      <i class="material-icons">add_circle</i> Create conversation
    </a>
  </div>
  <script>

  mixin.modal(this);

  this.conversations = [];

  joinConversation(e) {
    e.preventDefault();
    convos.connections(function(err, connections) {
      if (connections.length) {
        this.openModal('add-conversation', {connections: connections});
      }
      else {
        this.openModal('add-connection', {first: 1, next: 'add-conversation'});
      }
    }.bind(this));
  }

  this.on('mount', function() {
    convos.conversations(function(err, conversations) { this.conversations = conversations; this.update(); }.bind(this));
    convos.on('conversation', function(conversation) { this.conversations.unshift(conversation); this.update(); }.bind(this));
  });

  </script>
</sidenav-conversations>
