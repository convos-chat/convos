<chat>
  <nav>
    <sidebar-search user={user}></sidebar-search>
    <sidebar-notifications user={user}></sidebar-notifications>
    <sidebar-dialogues user={user}></sidebar-dialogues>
    <sidebar-settings user={user}></sidebar-settings>
  </nav>
  <dialogue dialogue={dialogue}></dialogue>
  <script>
  this.user = opts.user;
  this.dialogue = this.user.dialogues()[0];
  </script>
</chat>
