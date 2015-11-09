<conversation>
  <ul class="conversation collection">
    <li class="collection-item avatar" each={m, i in conversation.messages()}>
      <img src={parent.avatar(m)} alt={m.from} class="circle">
      <a href={'#autocomplete:' + m.from} class="title">{m.from}</a>
      <div class="message">{m.message}</div>
      <span class="secondary-content ts" title={m.ts * 1000}>{timestring(m.ts * 1000)}</span>
    </li>
  </ul>
  <script>

  mixin.time(this);

  avatar(m) {
    return m.avatar ? m.avatar : 'https://robohash.org/' + m.from + '.png';
  }

  this.on('update', function() {
    this.conversation = opts.conversation;
  });

  </script>
</conversation>
