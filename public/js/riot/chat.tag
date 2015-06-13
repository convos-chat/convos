<chat>
  <nav>
    <sidenav-search></sidenav-search>
    <sidenav-settings show={activeSidebar('settings')}></sidenav-settings>
    <sidenav-notifications show={activeSidebar('notifications')}></sidenav-notifications>
    <sidenav-conversations show={activeSidebar('conversations')}></sidenav-conversations>
    <sidenav-participants show={activeSidebar('participants')}></sidenav-participants>
    <ul class="actions">
      <sidenav-link href="#sidenav:settings" icon="mdi-action-settings" title="Settings" callback={changeSidebar} active={activeSidebar('settings')}></sidenav-link>
      <sidenav-link href="#sidenav:notifications" icon="mdi-social-notifications" title="Notifications" callback={changeSidebar} active={activeSidebar('notifications')}></sidenav-link>
      <sidenav-link href="#sidenav:conversations" icon="mdi-communication-forum" title="Conversations" callback={changeSidebar} active={activeSidebar('conversations')}></sidenav-link>
      <sidenav-link href="#sidenav:participants" icon="mdi-communication-contacts" title="Participants" callback={changeSidebar} active={activeSidebar('participants')}></sidenav-link>
    </ul>
  </nav>
  <main>
    <conversation each={conversations} target={id} show={current}></conversation>
    <div class="no-conversations valign-wrapper" if={!conversations.length}>
      <div class="valign center-align">
        <h5>No conversations</h5>
        <p class="grey-text">
          <!-- TODO: Highlight the item in the sidebar when the text below is clicked -->
          Click the "<i class="mdi-content-add-circle-outline"></i> Add conversation" link in the sidebar to find someone to talk to.
        </p>
      </div>
    </div>
    <user-input/>
  </main>

  this.conversations = [];
  this.modalBottomSheetShow = false;
  this.sidenav = localStorage.getItem('sidenav') || 'conversations';
  this.user = window.convos;

  activeSidebar(name) {
    return name == this.sidenav;
  }

  changeSidebar(e) {
    e.preventDefault();
    var $a = $(e.target).closest('a');
    this.sidenav = $a.attr('href').split('sidenav:')[1];
    localStorage.setItem('sidenav', this.sidenav);
    this.update();
  }

  this.on('mount', function() {
    if (!this.user.email()) return Router.route('login');
  });
</chat>
