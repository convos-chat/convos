<sidebar-dialogs>
  <div class="collection">
    <a href={d.href()} onclick={setCurrentDialog} class={parent.dialogClass(d)} each={d, i in user.dialogs()}>
      <i class="material-icons">{d.icon()}</i> {d.name()}
      <span class="on">{d.connection().protocol()}-{d.connection().name()}</span>
    </a>
    <a href='#settings/connections' class={parent.dialogClass(c)} each={c, i in user.connections()}>
      <i class="material-icons">device_hub</i> {c.protocol()}-{c.name()}
      <span class="on">{c.humanState()}</span>
    </a>
    <a href={href('settings/new-dialog')} class={activeClass('settings/new-dialog', 'collection-item')}>
      <i class="material-icons">add_circle</i> New dialog
    </a>
  </div>
  <script>
  this.user = opts.user;

  setCurrentDialog(e) {
    this.user.currentDialog(e.item.d);
    riot.update();
  }

  dialogClass(d) {
    return d == this.user.currentDialog() ? 'collection-item active' : 'collection-item';
  }

  activeClass(href, additional) {
    return additional + (location.hash.indexOf(href) != -1 ? ' active' : '');
  }

  href(url) {
    return '#' + (location.hash.indexOf(url) == -1 ? url : 'chat');
  }
  </script>
</sidebar-dialogs>
