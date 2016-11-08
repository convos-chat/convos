<template>
  <form autocomplete="off" class="convos-connection-editor" @submit.prevent>
    <div class="row">
      <div class="col s12">
        <h4>{{connection ? 'Edit "' + connection.name + '"' : "Add connection"}}</h4>
        <p>
          <template v-if="!user.connections.length">
            You need to add a connection before you can have a dialog.
          </template>
          <template v-if="user.connections.length">
            Click on the "Advanced" button for more settings. In most cases
            they are not requried to start chatting.
          </template>
          <template v-if="!user.connections.length && settings.default_server">
            We have filled in example values, but you can change them if you like.
            In most cases, you can just hit "Create" in the bottom to get started.
          </template>
        </p>
      </div>
    </div>
    <div class="row">
      <md-input :value.sync="server" focus="" :readonly="settings.forced_irc_server" cols="s8 m9">Server</md-input>
      <md-select :value.sync="tls" label="Secure connection" cols="s4 m3">
        <md-option :value="null" :selected="tls == null">Autodetect</md-option>
        <md-option value="0" :selected="tls == 0">No</md-option>
        <md-option value="1" :selected="tls == 1">Yes</md-option>
      </md-select>
    </div>
    <div class="row" v-if="showNickField">
      <md-input :value.sync="nick" placeholder="A nick can be generated for you">Nick</md-input>
    </div>
    <template v-if="advanced">
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
        <a v-link.literal="#" class="btn waves-effect waves-light" v-if="!user.connections.length || !user.dialogs.length">
          <i class="material-icons left">navigate_before</i>Back
        </a>
        <button @click="saveConnection" class="btn waves-effect waves-light">
          {{connection && !deleted ? 'Update' : 'Create'}} <i class="material-icons right">save</i>
        </button>
        <button @click.prevent="toggleAdvanced()" class="btn waves-effect waves-light">
          Advanced <i class="material-icons right">{{advanced ? "close" : "settings"}}</i>
        </button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">
          <i class="material-icons">delete</i>
        </a>
        <span v-if="connection && connection.state == 'disconnected'">{{connection.message || 'Click "update" to connect.'}}</span>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["user"],
  computed: {
    showNickField: function() {
      return this.selectedProtocol == "irc"; // will make this dynamic when there are more protocols in backend
    }
  },
  data: function() {
    return {
      advanced:         false,
      onConnectCommands: "",
      connection:       null,
      deleted:          false,
      errors:           [],
      password:         "",
      nick:             "",
      selectedProtocol: "irc",
      server:           "",
      tls:              null,
      username:         ""
    };
  },
  watch: {
    "settings.main": function(v, o) {
      this.errors = [];
      this.updateForm(this.user.getConnection(v.replace(/.*connection\//, "")));
    }
  },
  methods: {
    removeConnection: function() {
      var self = this;
      this.connection.remove(function(err) {
        if (err) return self.errors = err;
        self.connection = null;
        self.deleted = true;
        self.settings.main = "#connection";
      });
    },
    saveConnection: function() {
      var self       = this;
      var connection = this.connection || new Convos.Connection({user: this.user});
      var userinfo   = [this.username, this.password].join(":");
      var params     = [];

      userinfo = userinfo.match(/[^:]/) ? userinfo + "@" : "";
      connection.user = this.user;
      connection.url = this.selectedProtocol + "://" + userinfo + this.server;
      connection.on_connect_commands = this.onConnectCommands.split(/\n/).map(function(str) { return str.trim(); });

      if (this.nick) params.push("nick=" + this.nick);
      if (this.tls !== null) params.push("tls=" + this.tls);
      if (params.length) connection.url += "?" + params.join("&");

      this.errors = []; // clear error on post
      connection.save(function(err) {
        if (err) return self.errors = err;
        self.deleted = false;
        self.updateForm(this);
        if (self.settings.main.indexOf(this.connection_id) == -1) self.settings.main = "#create-dialog";
      });
    },
    toggleAdvanced: function(e) {
      this.advanced = !this.advanced;
      if (this.advanced) {
        var $main = $(this.$el).closest("main");
        this.$nextTick(function() {
          $main.animate({scrollTop: $main.height()}, "slow");
        });
      }
    },
    updateForm: function(connection) {
      var url = connection ? connection.url.parseUrl() : null;
      this.connection = connection;
      this.onConnectCommands = connection ? connection.on_connect_commands.join("\n") : "";
      this.password = url ? url.query.password || "" : "";
      this.nick = url ? url.query.nick || "" : "";
      this.server = url ? url.hostPort : this.settings.default_server;
      this.selectedProtocol = url ? url.scheme || "" : this.selectedProtocol;
      this.tls = url ? url.query.tls : null;
      this.username = url ? url.query.username : "";
      this.advanced = this.username ? true : false;
    }
  },
  ready: function() {
    this.updateForm(this.user.getConnection(this.settings.main.replace(/.*connection\//, "")));
  }
};
</script>
