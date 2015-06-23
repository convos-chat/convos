<sidenav-link>
  <li class={opts.active ? 'link active' : 'link'}>
    <a href={opts.href} class="waves-effect waves-teal" title={opts.title} onclick={opts.callback}>
      <i class="material-icons">{opts.icon || 'healing'}</i>
      <yield/>
    </a>
  </li>
</sidenav-link>
