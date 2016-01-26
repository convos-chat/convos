riot.tag2('chat', '<nav> <ul class="navbar"> <li class="{active: activeSidebar(\'search\')}"><a href="#sidebar:search" onclick="{changeSidebar}"><i class="material-icons">search</i></a></li> <li class="{active: activeSidebar(\'notifications\')}"><a href="#sidebar:notifications" onclick="{changeSidebar}"><i class="material-icons">notifications</i></a></li> <li class="{active: activeSidebar(\'conversations\')}"><a href="#sidebar:conversations" onclick="{changeSidebar}"><i class="material-icons">groups</i></a></li> <li class="{active: activeSidebar(\'settings\')}"><a href="#sidebar:settings" onclick="{changeSidebar}"><i class="material-icons">settings</i></a></li> </ul> <sidebar-search user="{user}" show="{activeSidebar(\'search\')}"></sidebar-search> <sidebar-settings user="{user}" show="{activeSidebar(\'settings\')}"></sidebar-settings> <sidebar-notifications user="{user}" show="{activeSidebar(\'notifications\')}"></sidebar-notifications> <sidebar-conversations user="{user}" show="{activeSidebar(\'conversations\')}"></sidebar-conversations> </nav> <main> <div class="no-conversations valign-wrapper" if="{!user.conversations().length}"> <div class="valign center-align"> <h5>No conversations</h5> <p class="grey-text"> Click the "Create conversation" link in the sidebar to find someone to talk to. </p> </div> </div> <conversation conversation="{conversation}" show="{conversation}"></conversation> <user-input conversation="{conversation}"></user-input> </main>', '', '', function(opts) {

  this.conversation = null;
  this.modalBottomSheetShow = false;
  this.sidebar = localStorage.getItem('sidebar') || 'conversations';
  this.user = opts.user;

  this.activeSidebar = function(name) {
    return name == this.sidebar;
  }.bind(this)

  this.changeSidebar = function(e) {
    var $a = $(e.target).closest('a');
    this.sidebar = $a.attr('href').split('sidebar:')[1];
    localStorage.setItem('sidebar', this.sidebar);
    this.update();
  }.bind(this)

  this.on('mount', function() {
    if (!this.user.email()) return this.parent.update({render:'login'});
  });

  this.on('update', function() {
    var p = riot.url.fragment();
    this.user.conversations().forEach(function(c, i) {
      if (c.url() == p) this.conversation = c;
    }.bind(this));
  });

}, '{ }');
