<template>
  <form autocomplete="off" class="convos-connection-settings" @submit.prevent>
    <div class="row" v-if="user.connections.length">
      <div class="col s12">
        <h5 v-if="connection">Edit {{connection.name}}</h5>
        <h4 v-if="!connection">Add connection</h4>
      </div>
    </div>
    <div class="row" v-if="!user.connections.length">
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
          Just fill in a <a href="#fillin" @click.prevent="fillIn">server name</a>
          and hit "Create" to get started.
        </p>
      </div>
    </div>
    <template v-if="connection">
      <div class="row">
        <md-input :value.sync="server" :placeholder="url.hostPort" :readonly="settings.forced_irc_server" cols="s12">Server</md-input>
      </div>
      <div class="row" v-if="connection">
        <md-select :value.sync="wantedState" label="State">
          <md-option value="connect" :selected="'connected' == connection.state">Connected</md-option>
          <md-option value="disconnect" :selected="'disconnected' == connection.state">Disconnected</md-option>
        </md-select>
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
        <button type="submit" @click="saveConnection" class="btn waves-effect waves-light">{{connection ? "Save" : "Create"}}</button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">Delete</a>
        <p v-if="connection">{{humanState()}}</p>
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
      username: "",
      wantedState: ""
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
    humanState: function() {
      if (this.connection.state == 'queued') return 'Connecting...';
      if (this.connection.getDialog("").frozen) return this.connection.getDialog("").frozen;
      return 'State: ' + this.connection.state.ucFirst();
    },
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
      var params = [];
      var userinfo;

      userinfo = [this.username, this.password].map(function(str) {
        return encodeURIComponent(str)
      }).join(":");

      userinfo = userinfo.match(/[^:]/) ? userinfo + "@" : "";
      connection.user = this.user;
      connection.wantedState = this.wantedState;
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
        self.user.ensureDialog({connection_id: this.connection_id, dialog_id: "", name: this.connection_id});
        self.settings.main = self.connection ? "#chat/" + this.connection_id + "/" : "#create-dialog";
      });
    },
    updateForm: function() {
      var nick = this.user.email.split("@")[0].replace(/\W+/g, "_");
      var url = this.connection ? this.connection.url.parseUrl() : null;
      var userinfo = url ? url.userinfo : [];
      this.wantedState = this.connection ? this.connection.wantedState : "connect";
      this.errors = [];
      this.url = url || {query: {nick: ""}};
      this.nick = url ? url.query.nick || nick : nick;
      this.onConnectCommands = url ? this.connection.on_connect_commands.join("\n") : "";
      this.server = url ? url.hostPort : this.settings.default_server || "";
      this.tls = url ? url.query.tls != false : null; // Need to use "==" instead of "===" http://dorey.github.io/JavaScript-Equality-Table/unified : ""/
      this.password = "";
      this.username = decodeURIComponent(userinfo[0] || "");
    }
  },
  ready: function() {
    this.updateForm();
  }
};
</script>
