<sidebar-conversations>
  <div class="collection">
    <a href={'#' + c.url()} class={parent.conversationClass(c)} each={c, i in user.conversations()}>
      <i class="material-icons">{c.icon()}</i> {c.name()}
    </a>
    <a href="#addConversation" onclick={addConversation} class="collection-item">
      <i class="material-icons">add_circle</i> Create conversation...
    </a>
  </div>
  <script>

  mixin.modal(this);

  this.user = opts.user;

  addConversation(e) {
    if (this.user.connections().length) {
      this.openModal('conversation-add', {user: this.user});
    }
    else {
      this.openModal('connection-add', {first: true, next: 'conversation-add', user: this.user});
    }
  }

  conversationClass(c) {
    return c == this.parent.conversation ? 'collection-item active' : 'collection-item';
  }

  </script>
</sidebar-conversations>
