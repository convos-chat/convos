<template>
  <form autocomplete="off" class="content" @submit.prevent>
    <div class="row" v-if="connection">
      <div class="col s12">
        <h5>Edit {{connection.name}}</h5>
      </div>
    </div>
    <template v-if="connection">
      <div class="row">
        <md-input :value.sync="server" :placeholder="url.hostPort" :readonly="settings.forced_irc_server" cols="s12">Server</md-input>
      </div>
      <div class="row">
        <md-input :value.sync="nick" :placeholder="url.query.nick">Nick</md-input>
      </div>
      <div class="row">
        <div class="col s12">
          <input type="checkbox" class="filled-in" id="form_tls" v-model="tls">
          <label for="form_tls">Secure connection (TLS)</label>
        </div>
      </div>
    </template>
    <template v-if="!connection">
      <div class="row">
        <md-input :value.sync="server" placeholder="Example: chat.freenode.net:6697" :readonly="settings.forced_irc_server" focus="true" cols="s6">Server</md-input>
        <md-input :value.sync="nick" placeholder="Example: jan_henning" cols="s6">Nick</md-input>
      </div>
    </template>
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
      <div class="row on-connect-commands">
        <md-textarea v-ref:occ :value.sync="onConnectCommands" placeholder="/msg NickServ identify supersecret">On Connect Commands (one per line)</md-textarea>
      </div>
    </template>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="col s12">
        <button @click="saveConnection" class="btn waves-effect waves-light">{{connection ? "Save" : "Create"}}</button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">Delete</a>
        <p v-if="connection">{{connection.state == 'connected' ? 'Status: Connected.' : connection.message || 'Click "save" to connect.'}}</p>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["connection", "user"],
  data: function() {
    return {
      advancedSettings: false,
      errors: [],
      url: {query: {nick: ""}},
      nick: "",
      onConnectCommands: "",
      server: "",
      tls: null,
      password: "",
      username: ""
    };
  },
  watch: {
    advancedSettings: function(v, o) {
      if (v) autosize(this.$refs.occ.$els.input);
    },
    connection: function(v, o) {
      this.updateForm();
    }
  },
  methods: {
    removeConnection: function() {
      var self = this;
      this.connection.remove(function(err) {
        if (err) return self.errors = err;
        self.settings.main = "#connection";
      });
    },
    saveConnection: function() {
      var self = this;
      var connection = this.connection || new Convos.Connection({user: this.user});
      var userinfo = [this.username, this.password].join(":");
      var params = [];

      userinfo = userinfo.match(/[^:]/) ? userinfo + "@" : "";
      connection.user = this.user;
      connection.url = "irc://" + userinfo + this.server;
      connection.on_connect_commands = this.onConnectCommands.split(/\n/).map(function(str) { return str.trim(); });

      if (this.nick) params.push("nick=" + this.nick);
      if (this.tls !== null) params.push("tls=" + (this.tls ? 1 : 0));
      if (params.length) connection.url += "?" + params.join("&");

      this.errors = []; // clear error on post
      connection.save(function(err) {
        if (err) return self.errors = err;
        self.deleted = false;
        self.updateForm(this);
        this.user.ensureDialog({connection_id: this.connection_id, name: this.connection_id});
        self.settings.main = "#chat/" + this.connection_id + "/";
      });
    },
    updateForm: function() {
      var nick = this.user.email.split("@")[0].replace(/\W+/g, "_");
      var url = this.connection ? this.connection.url.parseUrl() : null;
      this.errors = [];
      this.url = url || {query: {nick: ""}};
      this.nick = url ? url.query.nick || nick : nick;
      this.onConnectCommands = url ? this.connection.on_connect_commands.join("\n") : "";
      this.server = url ? url.hostPort : Convos.settings.default_server || "";
      this.tls = url ? url.query.tls != false : null; // Need to use "==" instead of "===" http://dorey.github.io/JavaScript-Equality-Table/unified : ""/
      this.password = url ? url.query.password : "";
      this.username = url ? url.query.username : "";
    }
  },
  ready: function() {
    this.updateForm();
  }
};
</script>
