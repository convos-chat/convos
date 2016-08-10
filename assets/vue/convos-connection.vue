<template>
  <div class="convos-connection is-sidebar">
    <header><convos-menu :user="user"></convos-menu></header>
    <div class="content">
      <div class="row">
        <div class="col s12">
          <h5>{{connection ? 'Edit "' + connection.name + '"' : "Create connection"}}</h5>
          <p v-if="!user.connections.length">
            You need to add a connection before you can have a dialog.
            <span v-if="defaultServer">
              We have filled in an example server, but you can connect to any server
              you like. "Username" and "password" are optional in most cases.
            </span>
            <span v-else>
              You need to fill in "server", but "username" and "password" are
              optional in most cases.
            </span>
          </p>
        </div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <input name="server" v-model="server" id="form_server" type="text" class="validate">
          <label for="form_server">Server</label>
        </div>
      </div>
      <div class="row" v-if="showNickField">
        <div class="input-field col s12">
          <input name="nick" v-model="nick" id="form_nick" type="text" class="validate">
          <label for="form_nick">Nick</label>
        </div>
      </div>
      <div class="row">
        <div class="input-field col s6">
          <input name="username" v-model="username" id="form_username" type="text" class="validate">
          <label for="form_username">Username</label>
        </div>
        <div class="input-field col s6">
          <input name="password" v-model="password" id="form_password" type="password" autocomplete="off" class="validate">
          <label for="form_password">Password</label>
        </div>
      </div>
      <div class="row" v-if="errors.length">
        <div class="input-field col s12"><div class="alert">{{errors[0].message}}</div></div>
      </div>
      <div class="row">
        <div class="input-field col s12">
          <button @click="saveConnection" class="btn waves-effect waves-light" type="submit">
            {{connection && !deleted ? 'Update' : 'Create'}} <i class="material-icons right">save</i>
          </button>
          <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">
            <i class="material-icons">delete</i>
          </a>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props:    ["settings", "user"],
  computed: {
    showNickField: function() {
      return this.selectedProtocol == "irc"; // will make this dynamic when there are more protocols in backend
    }
  },
  data: function() {
    return {
      connection:       null,
      deleted:          false,
      defaultServer:    this.settings.default_server || "",
      errors:           [],
      password:         "",
      nick:             "",
      selectedProtocol: "irc",
      server:           this.settings.default_server || "",
      username:         ""
    };
  },
  events: {
    locationchange: function(hash) {
      this.connection = this.user.getConnection(hash[1]);
      this.errors = [];
      this.updateForm(this.connection);
      if (!this.connection && hash[0] == "connections") this.replaceLocation("connections");
    }
  },
  methods: {
    removeConnection: function() {
      var self = this;
      this.connection.remove(function(err) {
        if (err) return self.errors = err;
        self.connection = null;
        self.deleted = true;
      });
    },
    saveConnection: function() {
      var self       = this;
      var connection = this.connection || new Convos.Connection({user: this.user});
      var userinfo   = [this.username, this.password].join(":");

      userinfo = userinfo.match(/[^:]/) ? userinfo + "@" : "";
      connection.user = this.user;
      connection.url = this.selectedProtocol + "://" + userinfo + this.server;

      if (this.nick)
        connection.url += "?nick=" + this.nick;

      this.errors = []; // clear error on post
      connection.save(function(err) {
        if (err) return self.errors = err;
        self.deleted = false;
        self.updateForm(this);
        location.hash = "connections/" + this.id;
      });
    },
    updateForm: function(connection) {
      var url = connection ? connection.url.parseUrl() : null;

      this.connection       = connection;
      this.password         = url ? url.query.password || "" : "";
      this.nick             = url ? url.query.nick || "" : "";
      this.server           = url ? url.hostPort : this.defaultServer;
      this.selectedProtocol = url ? url.scheme || "" : this.selectedProtocol;
      this.username         = url ? url.query.username : "";
    }
  }
};
</script>
