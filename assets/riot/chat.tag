<chat>
  <nav>
    <ul class="navbar">
      <li class={active: activeSidebar('search')}><a href="#sidenav:search" onclick={changeSidebar}><i class="material-icons">search</i></a></li>
      <li class={active: activeSidebar('notifications')}><a href="#sidenav:notifications" onclick={changeSidebar}><i class="material-icons">notifications</i></a></li>
      <li class={active: activeSidebar('conversations')}><a href="#sidenav:conversations" onclick={changeSidebar}><i class="material-icons">groups</i></a></li>
      <li class={active: activeSidebar('settings')}><a href="#sidenav:settings" onclick={changeSidebar}><i class="material-icons">settings</i></a></li>
    </ul>
    <sidenav-search user={user} show={activeSidebar('search')}></sidenav-search>
    <sidenav-settings user={user} show={activeSidebar('settings')}></sidenav-settings>
    <sidenav-notifications user={user} show={activeSidebar('notifications')}></sidenav-notifications>
    <sidenav-conversations user={user} show={activeSidebar('conversations')}></sidenav-conversations>
  </nav>
  <main>
    <div each={c, i in conversations} messages={c.messages} show={i == parent.activeConversation}>
      <conversation messages={c.messages} show={i == parent.activeConversation}></conversation>
    </div>
    <div class="no-conversations valign-wrapper" if={!conversations.length}>
      <div class="valign center-align">
        <h5>No conversations</h5>
        <p class="grey-text">
          <!-- TODO: Highlight the item in the sidebar when the text below is clicked -->
          Click the "Create conversation" link in the sidebar to find someone to talk to.
        </p>
      </div>
    </div>
    <user-input conversation={conversations[activeConversation]} />
  </main>
  <script>

  this.activeConversation = 0;
  this.conversations = [];
  this.modalBottomSheetShow = false;
  this.sidenav = localStorage.getItem('sidenav') || 'conversations';
  this.user = opts.user;

  activeSidebar(name) {
    return name == this.sidenav;
  }

  changeSidebar(e) {
    var $a = $(e.target).closest('a');
    this.sidenav = $a.attr('href').split('sidenav:')[1];
    localStorage.setItem('sidenav', this.sidenav);
    this.update();
  }

  this.on('mount', function() {
    if (!this.user.email()) return this.parent.update({render:'login'});
  });

  this.on('update', function() {
    var p = riot.url.fragment().replace(/^chat/, '/' + this.user.email());
    this.conversations.forEach(function(c, i) { if (c.path() == p) this.activeConversation = i; }.bind(this));
  });

  </script>
</chat>
