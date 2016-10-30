<template>
  <div class="convos-settings">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <h2 v-tooltip.literal="Welcome to Convos!">Convos</h2>
      <convos-header-links :toggle="true" :user="user"></convos-header-links>
    </header>
    <main v-if="showWelcomeMessage">
      <div class="row">
        <div class="col s12">
          <h4>Welcome to Convos!</h4>
          <p>
            Convos is the simplest way to use IRC. It is always online,
            and accessible to your web browser, both on desktop and mobile.
          </p>
          <p>
            To get started, you need to create a connection and join a dialog.
            You can have as many connections and dialogs as you like, and you can
            add more of them later on.
          </p>
            Adding a new connection or dialog can be done by clicking on
            "<a v-link.literal="#create-dialog">Join dialog</a>"
            in the left side menu.
          </p>
          <div class="divider"></div>
          <p>
            <a v-link.literal="#create-dialog" class="btn waves-effect waves-light">OK, I got it</a>
          </p>
        </div>
      </div>
    </main>
    <main v-if="this.settings.main.indexOf('#create-dialog') == 0">
      <convos-create-dialog :user="user"></convos-create-dialog>
    </main>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  computed: {
    showWelcomeMessage: function() {
      return this.settings.main.match(/\w/) ? false : true;
    }
  }
}
</script>
