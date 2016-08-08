<template>
  <div class="convos-create-dialog">
    <div class="row">
      <div class="col s12">
        <div class="actions">
          <a href="#chat"><i class="material-icons">close</i></a>
        </div>
        <h5>Create dialog</h5>
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
      <div class="input-field col s12">
        <md-select id="form_connection_id" :value.sync="connectionId">
          <md-option :value="c.id" :selected="connectionId == c.id" v-for="c in user.connections">{{c.protocol}}-{{c.name}}</md-option>
        </md-select>
        <label for="form_connection_id">Select connection</label>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <md-autocomplete :options="rooms" :value.sync="dialogName" @select="join" id="form_dialog_name"></md-autocomplete>
        <label for="form_dialog_name">Room or nick</label>
        <p v-if="message">{{message}}</p>
      </div>
    </div>
    <div class="row" v-if="errors.length">
      <div class="input-field col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" :disabled="!dialogName.length">
          Chat <i class="material-icons right">send</i>
        </button>
        <a href="#load" @click.prevent="load" class="btn waves-effect waves-light">
          Load <i class="material-icons right">refresh</i>
        </a>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {
      connectionId: "",
      dialogName:   "",
      message:      "",
      errors:       [],
      rooms:        []
    };
  },
  watch: {
    connectionId: function() {
      this.message = "";
    }
  },
  methods: {
    connection: function() {
      return this.user.getConnection(this.connectionId);
    },
    join: function(option) {
      this.connection().send("/join " + option.value);
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
        self.materializeComponent();
      });
    }
  }
};
</script>
