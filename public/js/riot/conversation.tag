<conversation>
  <ul class="conversation collection">
    <li each={message, i in conversation.messages} class={'collection-item avatar ' + (message.level || 'debug')}">
      <img src={message.avatar} alt={message.target} class="circle">
      <a href={'#autocomplete:' + message.target} class="title">{message.target}</a>
      <div>{message.message}</div>
      <span class="secondary-content">{message.ts}</span>
    </li>
  </ul>
</conversation>
