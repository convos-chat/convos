<template>
  <form autocomplete="off" class="convos-create-dialog" @submit.prevent>
    <div class="row">
      <div class="col s12">
        <h4>Join dialog</h4>
        <p v-if="!user.connections.length">
          You need to <a href="#connections">create a connection</a> before
          you can create or join any dialog.
        </p>
        <p v-if="user.connections.length">
          You can create a dialog with either a single user (by nick)
          or join a chat room (channel). Click "<a href="#load" @click.prevent="load">Load</a>"
          to get a list of available rooms. Note that loading the list
          from the server might take a while.
        </p>
      </div>
    </div>
    <div class="row">
      <md-select id="form_connection_id" :value.sync="connectionId" label="Select connection">
        <md-option :value="c.connection_id" :selected="connectionId == c.connection_id" v-for="c in user.connections">{{c.protocol}}-{{c.name}}</md-option>
      </md-select>
    </div>
    <div class="row">
      <md-autocomplete cols="m8" :options="rooms" :value.sync="dialogName" @select="selected">Room or nick</md-autocomplete>
      <md-input cols="m4" :value.sync="password" type="password">Password / key</md-input>
    </div>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="col s12">
        <a v-link="'#connection/' + connectionId" class="btn waves-effect waves-light" v-if="!user.dialogs.length">
          <i class="material-icons left">navigate_before</i>Back
        </a>
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
      connectionId: "",
      dialogName:   "",
      message:      "",
      password:     "",
      errors:       [],
      rooms:        []
    };
  },
  watch: {
    "connectionId": function() { this.message = ""; },
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
