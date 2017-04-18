<template>
  <div class="convos-settings">
    <main v-if="show == 'error'">
      <div class="row">
        <div class="col s12">
          <h4>{{error.title || "Not found"}}</h4>
          <p>{{error.message}}</p>
        </div>
      </div>
    </main>
    <main v-if="show == 'add_connection'">
      <convos-connection-settings :connection="new Convos.Connection()" :user="user"></convos-connection-settings>
    </main>
    <main v-if="show == 'create_dialog'">
      <convos-create-dialog :user="user"></convos-create-dialog>
    </main>
    <main v-if="show == 'help'">
      <convos-help :user="user"></convos-help>
    </main>
    <main v-if="show == 'profile'">
      <convos-profile :user="user"></convos-profile>
    </main>
  </div>
</template>
<script>
module.exports = {
  props: ["error", "user"],
  computed: {
    show: function() {
      return this.settings.main.indexOf("#help") == 0          ? "help"
           : this.settings.main.indexOf("#profile") == 0       ? "profile"
           : !this.user.connections.length                     ? "add_connection"
           : this.settings.main.indexOf("#connection") == 0    ? "add_connection"
           : this.settings.main.indexOf("#create-dialog") == 0 ? "create_dialog"
           :                                                     "error";
    }
  },
  methods: {
    fillIn: function() {
      this.$refs.settings.server = this.settings.default_server || "chat.freenode.net:6697";
      this.$refs.settings.onConnectCommands = "/join #convos";
    }
  }
}
</script>
