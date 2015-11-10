<conversation>
  <ul class="conversation collection">
    <li class="collection-item avatar" each={m, i in conversation.messages()}>
      <img src={parent.avatar(m)} alt={m.from} class="circle">
      <a href={'#autocomplete:' + m.from} class="title">{m.from}</a>
      <div class="message">{m.message}</div>
      <span class="secondary-content ts" title={m.ts}>{timestring(m.ts)}</span>
    </li>
  </ul>
  <script>

  mixin.time(this);

  avatar(m) {
    return m.avatar ? m.avatar : 'https://robohash.org/' + m.from + '.png';
  }

  this.on('update', function() {
    if (this.conversation == opts.conversation) return;
    this.conversation = opts.conversation;
    this.conversation.trigger('show');
  });

  </script>
</conversation>
