<template>
  <form autocomplete="off" class="content" @submit.prevent>
    <div class="row">
      <div class="col s12">
        <h4>Join dialog</h4>
      </div>
    </div>
    <div class="row">
      <md-select id="form_connection_id" :value.sync="connectionId" label="Select connection">
        <md-option :value="c.connection_id" :selected="connectionId == c.connection_id" v-for="c in user.connections">{{c.protocol}}-{{c.name}}</md-option>
        <md-option :value="">Create connection...</md-option>
      </md-select>
    </div>
    <template v-if="!connectionId">
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
    </template>
    <div class="row">
      <md-autocomplete cols="m8" :options="rooms" :value.sync="dialogName" @select="selected">Room or nick</md-autocomplete>
      <md-input cols="m4" :value.sync="password">Password / key</md-input>
    </div>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="col s12">
        <button @click="join" class="btn waves-effect waves-light" :disabled="!dialogName.length">
          Chat <i class="material-icons right">send</i>
        </button>
        <a href="#load" @click.prevent="load" class="btn waves-effect waves-light" v-tooltip="message">Load dialogs</a>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {
      advanced:         false,
      connectionId:     "",
      dialogName:       "",
      errors:           [],
      message:          "",
      nick:             "",
      password:         "",
      rooms:            [],
      selectedProtocol: "irc",
      server:           "",
      tls:              null,
      username:         ""
    };
  },
  watch: {
    "connectionId": function() { this.message = "" },
    "settings.main": function(v, o) { this.updateForm() }
  },
  methods: {
    connection: function() {
      return this.user.getConnection(this.connectionId);
    },
    selected: function(option) {
      this.dialogName = option.value;
    },
    join: function(option) {
      var command = this.dialogName;
      if (this.password) command += " " + this.password;
      if (this.dialogName) this.connection().send("/join " + command);
      this.dialogName = "";
    },
    load: function(e) {
      var self = this;
      this.errors = [];
      this.message = "Loading rooms...";
      this.connection().rooms(function(err, rooms) {
        if (err) return self.errors = err;
        var s = rooms.length == 1 ? "" : "s";
        self.dialogName = "";
        self.message = rooms.length ? "Found " + rooms.length + " room" + s + "." : "No rooms found.";
        self.rooms = rooms.map(function(r) {
          if (!r.topic) r.topic = "No topic";
          return {
            text: [r.name, r.topic].join(" - "),
            title: r.topic,
            value: r.name
          };
        });
      });
    },
    updateForm: function() {
      var dialogName = this.settings.main.match(/create-dialog\/([^\/]+)/);
      this.dialogName = dialogName ? dialogName[1] : "";
    }
  },
  ready: function() {
    this.updateForm();
  }
};
</script>
