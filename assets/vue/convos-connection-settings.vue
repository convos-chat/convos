<template>
  <form autocomplete="off" class="convos-connection-settings" @submit.prevent>
    <div class="row" v-if="user.connections.length">
      <div class="col s12">
        <h5 v-if="connection.url">Edit {{connection.name}}</h5>
        <h4 v-if="!connection.url">Add connection</h4>
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
          <template v-if="settings.forced_irc_server">
          This installation of Convos is locked to a specific "Server",
          so just hit "Create" to start chatting.
          </template>
          <template v-else>
          "Server" below has a default value, but you can change it to
          <a href="http://www.irchelp.org/networks/" target="_blank">any server</a>
          you want. Once a server is entered, you can hit "Create" to start chatting.
          Note that Convos automatically detects if the server supports TLS/SSL on the
          port provided.
          </template>
        </p>
      </div>
    </div>
    <template v-if="connection.url">
      <div class="row">
        <md-input :value.sync="server" placeholder="Example: chat.freenode.net:6697" :readonly="settings.forced_irc_server" cols="s12" name="server">Server</md-input>
      </div>
      <div class="row">
        <md-select :value.sync="wantedState" label="Wanted state">
          <md-option value="connected" :selected="'connected' == wantedState">Connected</md-option>
          <md-option value="disconnected" :selected="'disconnected' == wantedState">Disconnected</md-option>
        </md-select>
      </div>
      <div class="row">
        <md-input :value.sync="nick" :placeholder="defaultNick">Nick</md-input>
      </div>
      <div class="row">
        <div class="col s12">
          <input type="checkbox" class="filled-in" id="form_tls" v-model="tls">
          <label for="form_tls">Secure connection (TLS)</label>
          <template v-if="tls">
            <input type="checkbox" class="filled-in" id="form_tls_verify" v-model="tls_verify">
            <label for="form_tls_verify">Verify certificate (TLS)</label>
          </template>
        </div>
      </div>
    </template>
    <template v-if="!connection.url">
      <div class="row">
        <md-input :value.sync="server" placeholder="Example: chat.freenode.net:6697" :readonly="settings.forced_irc_server" cols="s6" name="server">Server</md-input>
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
        <md-input :value.sync="password" cols="s6" type="password" :readonly="settings.forced_irc_server">Password</md-input>
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
        <button type="submit" @click="saveConnection" class="btn waves-effect waves-light">{{connection.url ? "Save" : "Create"}}</button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection.url">Delete</a>
        <p v-if="connection.url">{{humanState()}}</p>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {
      advancedSettings: false,
      connection: null,
      defaultNick: this.user.email.split("@")[0].replace(/\W+/g, "_"),
      errors: [],
      nick: "",
      onConnectCommands: "",
      server: "",
      tls: null,
      tls_verify: true,
      password: "",
      username: "",
      wantedState: ""
    };
  },
  watch: {
    'advancedSettings': function(v, o) {
      if (v) autosize(this.$refs.occ.$els.input);
    },
    'settings.main': function(v, o) {
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
      var connection = this.connection;
      var attrs = {url: new Url("irc://" + this.server)};

      if (this.nick) attrs.url.param("nick", this.nick);
      if (this.tls !== null) attrs.url.param("tls", this.tls ? 1 : 0);
      if (this.tls) attrs.url.param("tls_verify", this.tls_verify ? 1 : 0);

      attrs.on_connect_commands = this.onConnectCommands.split(/\n/).map(function(str) { return str.trim(); });
      attrs.url.user = this.username;
      attrs.url.pass = this.password;
      attrs.wanted_state = this.wantedState;
      attrs.url = attrs.url.toString();

      this.errors = []; // clear error on post
      connection.save(attrs, function(err) {
        if (err) return self.errors = err;
        self.deleted = false;
        self.updateForm(this);
        self.user.ensureDialog({connection_id: this.connection_id, dialog_id: "", name: this.connection_id});
        self.settings.main = this == connection ? "#chat/" + this.connection_id + "/" : "#create-dialog";
      });
    },
    updateForm: function() {
      var url, dialog = this.user.activeDialog();
      if (DEBUG.info) console.log("[editConnection]", dialog ? dialog.connection_id : "New connection");

      this.connection = dialog ? dialog.connection() : new Convos.Connection({user: this.user});
      this.errors = [];
      this.onConnectCommands = this.connection.on_connect_commands.join("\n");
      this.wantedState = this.connection.wanted_state || "connected";

      url = new Url(this.connection.url || "//0.0.0.0");
      this.nick = url.param("nick") || this.defaultNick;
      this.password = url.pass || "";
      this.server = url.host || this.settings.default_server || "";
      this.tls = this.connection.url ? url.param("tls") : null;
      this.tls_verify = this.connection.url ? Boolean(parseInt(url.param("tls_verify"))) : true;
      this.username = url.user || "";

      if (url.port) this.server += ":" + url.port;
    }
  },
  created: function() {
    this.updateForm();
  }
};
</script>
