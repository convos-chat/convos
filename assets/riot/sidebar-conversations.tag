<sidebar-conversations>
  <div class="collection">
    <a href={c.href('activate')} class={parent.conversationClass(c)} each={c, i in user.conversations()}>
      <i class="material-icons">{c.icon()}</i> {c.name()}
      <span class="on">{c.connection().protocol()}-{c.connection().name()}</span>
    </a>
    <a href={c.href('activate')} class={parent.conversationClass(c)} each={c, i in user.connections()}>
      <i class="material-icons">device_hub</i> {c.protocol()}-{c.name()}
      <span class="on">{c.humanState()}</span>
    </a>
    <a href="#new-conversation" class="collection-item">
      <i class="material-icons">add_circle</i> New conversation
    </a>
  </div>
  <script>
  this.user = opts.user;

  conversationClass(c) {
    return c == this.parent.conversation ? 'collection-item active' : 'collection-item';
  }

  </script>
</sidebar-conversations>
