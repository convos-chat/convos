<template>
  <div class="convos-settings">
    <header>
      <convos-toggle-dialogs :user="user"></convos-toggle-dialogs>
      <h2 data-hint="Welcome to Convos!">{{header()}}</h2>
      <convos-menu :toggle="true" :user="user"></convos-menu>
    </header>
    <div class="section" v-if="showWelcomeMessage()">
      <div class="row">
        <div class="col s12">
          <h4>Welcome to Convos!</h4>
          <p>
            Convos is the simplest way to use IRC. It is always online,
            and accessible to your web browser, both on desktop and mobile.
          </p>
          <p>
            Before you can start chatting, you need to create a connection.
            You can have as many connections as you like, and you can add
            more of them later on.
          </p>
            To add a connection, click on
            "<a v-link.literal="#connection">Add connection</a>"
            in the left side menu, or click "Continue" below.
          </p>
          <div class="divider"></div>
          <p>
            <a v-link="connectionLink()" class="btn waves-effect waves-light">
              <i class="material-icons right">navigate_next</i>Continue
            </a>
          </p>
        </div>
      </div>
    </div>
    <div class="section" v-if="this.settings.main.indexOf('#connection') == 0">
      <convos-connection-editor :user="user"></convos-connection-editor>
    </div>
    <div class="section" v-if="this.settings.main.indexOf('#create-dialog') == 0">
      <convos-create-dialog :user="user"></convos-create-dialog>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  methods: {
    connectionLink: function() {
      var connections = this.user.connections;
      return '#connection' + (connections.length ? '/' + connections[0].id : '');
    },
    header: function() {
      if (this.settings.main.indexOf('#connection') == 0) return "Connection";
      if (this.settings.main.indexOf('#create-dialog') == 0) return "Dialog";
      return "Convos";
    },
    showWelcomeMessage: function() {
      return this.settings.main.match(/\w/) ? false : true;
    }
  }
}
</script>
