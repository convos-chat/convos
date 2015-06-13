<sidenav-conversations>
  <ul class="sidenav">
    <sidenav-link each={conversations} icon={icon} href={path}>{name}</sidenav-link>
    <li class="conversation link">
      <a href="#add-conversation" class="waves-effect waves-teal" onclick={addConversation}>
        <i class="mdi-content-add-circle-outline"></i>
        Add conversation
      </a>
    </li>
  </ul>

  mixin.modal(this);
  this.conversations = [];
  this.addConversationTag = false;

  addConversation(e) {
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
    convos.conversations(function(err, conversations) {
      this.conversations = conversations;
      conversations.forEach(function(conversation) {
        conversation.icon = conversation['users'] ? 'mdi-social-group' : 'mdi-social-person';
      });
      this.update();
    }.bind(this));
  });
</sidenav-conversations>
