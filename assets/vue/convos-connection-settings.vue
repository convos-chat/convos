<template>
  <form autocomplete="off" class="content" @submit.prevent>
    <div class="row">
      <div class="col s12">
        <h5>Edit {{connection.name}}</h5>
      </div>
    </div>
    <div class="row">
      <md-input :value.sync="server" focus="" :readonly="settings.forced_irc_server" cols="s12">Server</md-input>
    </div>
    <div class="row">
      <md-input :value.sync="nick" placeholder="A nick can be generated for you">Nick</md-input>
    </div>
    <div class="row">
      <div class="col s12">
        <input type="checkbox" class="filled-in" id="form_tls" v-model="tls">
        <label for="form_tls">Secure connection (TLS)</label>
      </div>
    </div>
    <div class="row">
      <div class="col s12">
        <input type="checkbox" class="filled-in" id="form_advanced_settings" v-model="advancedSettings">
        <label for="form_advanced_settings">Advanced settings...</label>
      </div>
    </div>
    <template v-if="advancedSettings">
      <div class="row">
        <md-input :value.sync="username" cols="s6">Username</md-input>
        <md-input :value.sync="password" cols="s6" type="password">Password</md-input>
      </div>
      <div class="row">
        <md-textarea :value.sync="onConnectCommands">On Connect Commands (one per line)</md-textarea>
      </div>
    </template>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="col s12">
        <button @click="saveConnection" class="btn waves-effect waves-light">Save</button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">Delete</a>
        <p>{{connection.state == 'connected' ? 'Status: Connected.' : connection.message || 'Click "save" to connect.'}}</p>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["connection", "user"],
  mixins: [Convos.mixin.connectionEditor],
  data: function() {
    return {
      advancedSettings: false,
      errors: [],
      nick: "",
      onConnectCommands: "",
      server: "",
      tls: false,
      password: "",
      username: ""
    };
  },
  watch: {
    connection: function(v, o) { this.updateForm() }
  },
  methods: {
    removeConnection: function() {
      var self = this;
      this.connection.remove(function(err) {
        if (err) return self.errors = err;
        self.settings.main = "#connection";
      });
    },
    updateForm: function() {
      var url = this.connection.url.parseUrl();
      this.errors = [];
      this.nick = url.query.nick || this.user.email.split("@")[0];
      this.onConnectCommands = this.connection.on_connect_commands.join("\n");
      this.server = url.hostPort;
      this.tls = url.query.tls != false; // Need to use "==" instead of "===" http://dorey.github.io/JavaScript-Equality-Table/unified/
      this.password = url.query.password;
      this.username = url.query.username;
    }
  },
  ready: function() {
    this.updateForm();
  }
};
</script>
