<conversation>
  <ul class="conversation collection">
    <li each={conversations} class={'collection-item avatar ' + (level || 'debug')}">
      <img src={avatar} alt={target} class="circle">
      <a href={'#autocomplete:' + target} class="title">{target}</a>
      <div>{message}</div>
      <span class="secondary-content">{ts}</span>
    </li>
  </ul>
</conversation>
