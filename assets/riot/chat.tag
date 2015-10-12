<chat>
  <nav>
    <ul class="navbar">
      <li class={active: activeSidebar('search')}><a href="#sidebar:search" onclick={changeSidebar}><i class="material-icons">search</i></a></li>
      <li class={active: activeSidebar('notifications')}><a href="#sidebar:notifications" onclick={changeSidebar}><i class="material-icons">notifications</i></a></li>
      <li class={active: activeSidebar('conversations')}><a href="#sidebar:conversations" onclick={changeSidebar}><i class="material-icons">groups</i></a></li>
      <li class={active: activeSidebar('settings')}><a href="#sidebar:settings" onclick={changeSidebar}><i class="material-icons">settings</i></a></li>
    </ul>
    <sidebar-search user={user} show={activeSidebar('search')}></sidebar-search>
    <sidebar-settings user={user} show={activeSidebar('settings')}></sidebar-settings>
    <sidebar-notifications user={user} show={activeSidebar('notifications')}></sidebar-notifications>
    <sidebar-conversations user={user} show={activeSidebar('conversations')}></sidebar-conversations>
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
  this.sidebar = localStorage.getItem('sidebar') || 'conversations';
  this.user = opts.user;

  activeSidebar(name) {
    return name == this.sidebar;
  }

  changeSidebar(e) {
    var $a = $(e.target).closest('a');
    this.sidebar = $a.attr('href').split('sidebar:')[1];
    localStorage.setItem('sidebar', this.sidebar);
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
