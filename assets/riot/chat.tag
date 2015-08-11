<chat>
  <nav>
    <ul class="navbar">
      <li class={active: activeSidebar('search')}><a href="#sidenav:search" onclick={changeSidebar}><i class="material-icons">search</i></a></li>
      <li class={active: activeSidebar('notifications')}><a href="#sidenav:notifications" onclick={changeSidebar}><i class="material-icons">notifications</i></a></li>
      <li class={active: activeSidebar('conversations')}><a href="#sidenav:conversations" onclick={changeSidebar}><i class="material-icons">groups</i></a></li>
      <li class={active: activeSidebar('settings')}><a href="#sidenav:settings" onclick={changeSidebar}><i class="material-icons">settings</i></a></li>
    </ul>
    <sidenav-search show={activeSidebar('search')}></sidenav-search>
    <sidenav-settings show={activeSidebar('settings')}></sidenav-settings>
    <sidenav-notifications show={activeSidebar('notifications')}></sidenav-notifications>
    <sidenav-conversations show={activeSidebar('conversations')}></sidenav-conversations>
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
          Click the "<i class="material-icons">add_circle</i> Add conversation" link in the sidebar to find someone to talk to.
        </p>
      </div>
    </div>
    <user-input conversation={conversations[activeConversation]} />
  </main>
  <script>

  mixin.http(this);

  this.activeConversation = 0;
  this.conversations = [];
  this.modalBottomSheetShow = false;
  this.sidenav = localStorage.getItem('sidenav') || 'conversations';
  this.user = this.convos || opts.convos;

  activeSidebar(name) {
    return name == this.sidenav;
  }

  changeSidebar(e) {
    var $a = $(e.target).closest('a');
    this.sidenav = $a.attr('href').split('sidenav:')[1];
    localStorage.setItem('sidenav', this.sidenav);
    this.update();
  }

  loadMessages() {
    var conversation = this.conversations[this.activeConversation];
    if (!conversation || conversation.messages) return;
    conversation.messages = [];
    this.httpGet(conversation.messagesUrl(), {}, function(err, data) {
      if (err) throw err;
      conversation.messages = data.responseJSON;
      this.update();
    });
  }

  this.on('mount', function() {
    if (!this.user.email()) return Router.route('login');
    this.user.conversations(function(err, conversations) { this.conversations = conversations; this.loadMessages(); }.bind(this));
    this.user.on('conversation', function(conversation) { this.conversations.unshift(conversation); this.loadMessages(); }.bind(this));
  });

  this.on('update', function() {
    var p = Router.url().path.replace(/^chat/, '/' + this.user.email());
    this.conversations.forEach(function(c, i) { if (c.path() == p) this.activeConversation = i; }.bind(this));
  });

  </script>
</chat>
