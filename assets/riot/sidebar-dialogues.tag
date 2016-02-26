<sidebar-dialogues>
  <div class="collection">
    <a href={c.href('activate')} class={parent.dialogueClass(c)} each={c, i in user.dialogues()}>
      <i class="material-icons">{c.icon()}</i> {c.name()}
      <span class="on">{c.connection().protocol()}-{c.connection().name()}</span>
    </a>
    <a href={c.href('activate')} class={parent.dialogueClass(c)} each={c, i in user.connections()}>
      <i class="material-icons">device_hub</i> {c.protocol()}-{c.name()}
      <span class="on">{c.humanState()}</span>
    </a>
    <a href={href('settings/new-dialogue')} class={activeClass('settings/new-dialogue', 'collection-item')}>
      <i class="material-icons">add_circle</i> New dialogue
    </a>
  </div>
  <script>
  this.user = opts.user;

  dialogueClass(c) {
    return c == this.parent.dialogue ? 'collection-item active' : 'collection-item';
  }

  activeClass(href, additional) {
    return additional + (location.hash.indexOf(href) != -1 ? ' active' : '');
  }

  href(url) {
    return '#' + (location.hash.indexOf(url) == -1 ? url : 'chat');
  }
  </script>
</sidebar-dialogues>
