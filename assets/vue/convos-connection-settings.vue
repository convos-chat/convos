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
        <p>{{connection.state == 'connected' ? 'Status: Connected.' : connection.message || 'Click "update" to connect.'}}</p>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["connection", "user"],
  mixins: [Convos.mixin.connectionEditor],
  data: function() {
    var url = this.connection.url.parseUrl();
    return {
      advancedSettings: false,
      errors: [],
      url: url,
      nick: url.query.nick || this.user.email.split("@")[0],
      onConnectCommands: this.connection.on_connect_commands.join("\n"),
      server: url.hostPort,
      tls: url.query.tls ? true : false,
      password: url.query.password,
      username: url.query.username
    };
  },
  methods: {
    removeConnection: function() {
      var self = this;
      this.connection.remove(function(err) {
        if (err) return self.errors = err;
        self.settings.main = "#connection";
      });
    }
  }
};
</script>
