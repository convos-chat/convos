<sidenav-rooms>
  <ul class="sidenav">
    <sidenav-link each={rooms} icon={icon} href={path}>{name}</sidenav-link>
    <li class="conversation link">
      <a href="#add-conversation" class="waves-effect waves-teal" onclick={addConversation}>
        <i class="mdi-content-add-circle-outline"></i>
        Add conversation
      </a>
    </li>
    <li class="alert" if={!rooms.length}>
      <div class="alert teal lighten-2">
        Tip: Click the <i class="mdi-content-add-circle-outline"></i> above
        to find someone to to talk to.
      </div>
    </li>
  </ul>

  mixin.http(this);
  this.rooms = [];

  addConversation(e) {
    e.preventDefault();
    window.TODO('addConversation');
  }

  this.on('mount', function() {
    this.httpCachedGet(apiUrl('/rooms'), {}, function(err, xhr) {
      if (Array.isArray(xhr.responseJSON)) {
        xhr.responseJSON.forEach(function(room) {
          room.icon = room.name.match(window.MULTI_USER_ROOM_RE) ? 'mdi-social-group' : 'mdi-social-person';
        });
        this.rooms = xhr.responseJSON;
        this.update();
      }
    });
  });
</sidenav-rooms>
