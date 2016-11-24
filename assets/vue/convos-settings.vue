<template>
  <div class="convos-settings">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <h2 v-tooltip.literal="Welcome to Convos!">Convos</h2>
      <convos-header-links :toggle="true" :user="user"></convos-header-links>
    </header>
    <main v-if="show == 'wizard'">
      <div class="row">
        <div class="col s12">
          <h4>Welcome to Convos!</h4>
          <p>
            Convos is the simplest way to use IRC. It is always online,
            and accessible in your web browser, both on desktop and mobile.
          </p>
          <p>
            Before you can start chatting, you need to create a connection.
            You can add more connections later on if you need.
          </p>
          <p v-if="settings.default_server">
            If you don't have any special preferences, you can just hit "Create" to get started.
          </p>
          <p v-if="!settings.default_server">
            Just fill in a <a href="https://en.wikipedia.org/wiki/Internet_Relay_Chat#Networks" target="_blank">server name</a>
            and hit "Create" to get started.
          </p>
        </div>
      </div>
      <convos-connection-settings :user="user"></convos-connection-settings>
    </main>
    <main v-if="show == 'add_connection'">
      <div class="row">
        <div class="col s12">
          <h4>Add connection</h4>
        </div>
      </div>
      <convos-connection-settings :connection="null" :user="user"></convos-connection-settings>
    </main>
    <main v-if="show == 'create_dialog'">
      <convos-create-dialog :user="user"></convos-create-dialog>
    </main>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  computed: {
    show: function() {
      return !this.user.connections.length                     ? "wizard"
           : this.settings.main.indexOf("#connection") == 0    ? "add_connection"
           : this.settings.main.indexOf("#create-dialog") == 0 ? "create_dialog"
           :                                                     "wizard";
    }
  }
}
</script>
