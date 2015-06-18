<sidenav-conversations>
  <ul class="sidenav">
    <sidenav-link each={obj, i in conversations} active={i == parent.active} icon={obj.icon()} href={obj.url()}>{obj.name()}</sidenav-link>
    <li class="conversation link">
      <a href="#add/conversation" class="waves-effect waves-teal" onclick={joinConversation}>
        <i class="mdi-content-add-circle-outline"></i>
        Add conversation
      </a>
    </li>
  </ul>
  <script>

  mixin.modal(this);

  this.active = 0;
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
