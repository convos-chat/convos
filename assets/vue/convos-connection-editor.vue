<template>
  <div class="convos-connection-editor">
    <div class="row">
      <div class="col s12">
        <h4>{{connection ? 'Edit "' + connection.name + '"' : "Create connection"}}</h4>
        <p>
          <template v-if="!user.connections.length">
            You need to add a connection before you can have a dialog.
          </template>
          <template v-if="user.connections.length">
            You need to fill in "server", but "username" and "password" are
            optional in most cases.
          </template>
          <template v-if="!user.connections.length && defaultServer">
            We have filled in example values, but you can change them if you like.
            In most cases, you can just hit "Create" in the bottom to get started.
          </template>
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
        <input name="nick" v-model="nick" id="form_nick" type="text" class="validate" placeholder="A nick can be generated for you">
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
        <a v-link.literal="#" class="btn waves-effect waves-light" v-if="!user.connections.length || !user.dialogs.length">
          <i class="material-icons left">navigate_before</i>Back
        </a>
        <button @click="saveConnection" class="btn waves-effect waves-light">
          {{connection && !deleted ? 'Update' : 'Create'}} <i class="material-icons right">save</i>
        </button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">
          <i class="material-icons">delete</i>
        </a>
      </div>
    </div>
  </div>
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
      connection:       null,
      deleted:          false,
      defaultServer:    "",
      errors:           [],
      password:         "",
      nick:             "",
      selectedProtocol: "irc",
      server:           "",
      username:         ""
    };
  },
  watch: {
    'settings.main': function(v, o) {
      this.connection = this.user.getConnection(v.replace(/.*connection\//, ''));
    }
  },
  methods: {
    removeConnection: function() {
      var self = this;
      this.connection.remove(function(err) {
        if (err) return self.errors = err;
        self.connection = null;
        self.deleted = true;
        self.settings.main = '#connection';
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
        self.settings.main = '#' + (this.user.dialogs.length ? 'connections/' + this.id : 'create-dialog');
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
  },
  ready: function() {
    this.$nextTick(function() { this.$el.querySelector('#form_server').focusOnDesktop() });
    this.connection = this.user.getConnection(this.settings.main.replace(/.*connection\//, ''));
    this.defaultServer = this.settings.default_server;
    this.server = this.settings.default_server;
  }
};
</script>
