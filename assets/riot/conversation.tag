<conversation>
  <ul class="conversation collection">
    <li each={m, i in opts.messages} class="collection-item avatar">
      <img src={parent.avatar(m)} alt={m.sender} class="circle">
      <a href={'#autocomplete:' + m.sender} class="title">{m.sender}</a>
      <div class="message">{m.message}</div>
      <span class="secondary-content ts" title={m.timestamp + '+0000'}>{timestring(m.timestamp)}</span>
    </li>
  </ul>
  <script>

  avatar(m) {
    return m.avatar ? m.avatar : 'http://retroavatar.appspot.com/api?name=' + m.sender;
  }

  mixin.time(this);

  </script>
</conversation>
