<chat>
  <nav>
    <sidenav-search></sidenav-search>
    <sidenav-settings if={activeSidebar('settings')}></sidenav-settings>
    <sidenav-notifications if={activeSidebar('notifications')}></sidenav-notifications>
    <sidenav-rooms if={activeSidebar('rooms')}></sidenav-rooms>
    <sidenav-participants if={activeSidebar('participants')}></sidenav-participants>
    <ul class="actions">
      <sidenav-link href="#sidenav:settings" icon="mdi-action-settings" title="Settings" callback={changeSidebar} active={activeSidebar('settings')}></sidenav-link>
      <sidenav-link href="#sidenav:notifications" icon="mdi-social-notifications" title="Notifications" callback={changeSidebar} active={activeSidebar('notifications')}></sidenav-link>
      <sidenav-link href="#sidenav:rooms" icon="mdi-communication-forum" title="Conversations" callback={changeSidebar} active={activeSidebar('rooms')}></sidenav-link>
      <sidenav-link href="#sidenav:participants" icon="mdi-communication-contacts" title="Participants" callback={changeSidebar} active={activeSidebar('participants')}></sidenav-link>
    </ul>
  </nav>
  <main>
    <conversation/>
    <user-input/>
  </main>

  this.sidenav = localStorage.getItem('sidenav') || 'rooms';

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
</chat>
