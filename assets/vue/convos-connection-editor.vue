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
      <md-select :value.sync="tls" label="Secure connection" cols="s12">
        <md-option :value="null" :selected="tls == null">Autodetect</md-option>
        <md-option value="0" :selected="tls == 0">No</md-option>
        <md-option value="1" :selected="tls == 1">Yes</md-option>
      </md-select>
    </div>
    <div class="row">
      <md-input :value.sync="nick" placeholder="A nick can be generated for you">Nick</md-input>
    </div>
    <div class="row">
      <div class="col s12">
        <input v-model="advanced" type="checkbox" class="filled-in" id="form_advanced">
        <label for="form_advanced">Advanced settings...</label>
      </div>
    </div>
    <template v-if="advanced">
      <div class="row">
        <md-input :value.sync="username" cols="s12">Username</md-input>
      </div>
      <div class="row">
        <md-input :value.sync="password" cols="s12" type="password">Password</md-input>
      </div>
    </template>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row submit">
      <div class="col s12">
        <button @click="saveConnection" class="btn waves-effect waves-light">Update</button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">Delete</button>
        <span v-if="connection.state == 'disconnected'">{{connection.message || 'Click "update" to connect.'}}</span>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["connection", "user"],
  data: function() {
    return {
      advanced:         false,
      errors:           [],
      password:         "",
      nick:             "",
      selectedProtocol: "irc",
      server:           "",
      tls:              null,
      username:         ""
    };
  },
  methods: {
    removeConnection: function() {
      var self = this;
      this.connection.remove(function(err) {
        if (err) return self.errors = err;
        self.settings.main = "#create-dialog";
      });
    },
    saveConnection: function() {
      var self       = this;
      var userinfo   = [this.username, this.password].join(":");
      var params     = [];

      userinfo = userinfo.match(/[^:]/) ? userinfo + "@" : "";
      this.connection.user = this.user;
      this.connection.url = this.selectedProtocol + "://" + userinfo + this.server;

      if (this.nick) params.push("nick=" + this.nick);
      if (this.tls !== null) params.push("tls=" + this.tls);
      if (params.length) this.connection.url += "?" + params.join("&");

      this.errors = []; // clear error on post
      this.connection.save(function(err) {
        if (err) return self.errors = err;
        self.updateForm();
        if (self.settings.main.indexOf(this.connection_id) == -1) self.settings.main = "#create-dialog";
      });
    },
    updateForm: function() {
      var url = this.connection.url.parseUrl();

      this.password         = url ? url.query.password || "" : "";
      this.nick             = url ? url.query.nick || "" : "";
      this.server           = url ? url.hostPort : this.settings.default_server;
      this.selectedProtocol = url ? url.scheme || "" : this.selectedProtocol;
      this.tls              = url ? url.query.tls : null;
      this.username         = url ? url.query.username : "";
      this.advanced         = this.username ? true : false;
    }
  },
  ready: function() {
    this.updateForm();
  }
};
</script>
