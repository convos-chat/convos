<sidenav-link>
  <a href={opts.href} class={opts.active ? 'collection-item active' : 'collection-item'} title={opts.title} onclick={opts.callback}>
    <i class="material-icons">{opts.icon || 'healing'}</i>
    <yield/>
    <span class="badge new" if={opts.new}>{opts.new}</span>
  </a>
</sidenav-link>
