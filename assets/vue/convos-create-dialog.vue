<template>
  <form autocomplete="off" class="convos-create-dialog" @submit.prevent>
    <div class="row">
      <div class="col s12">
        <h4>Join dialog</h4>
        <p>
          Enter the name of a dialog to either search for the known dialogs,
          or to create a new chat room.
        </p>
      </div>
    </div>
    <div class="row">
      <md-select @change="updateForm" value="" label="Select connection">
        <md-option :value="c.connection_id" :selected="connection == c" v-for="c in user.connections">{{c.protocol}}-{{c.name}}</md-option>
        <md-option value="">Create new connection...</md-option>
      </md-select>
    </div>
    <div class="row">
      <convos-dialog-chooser :value.sync="dialogName" :options="rooms" @select="join"></convos-dialog-chooser>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {
      connection: new Convos.Connection({}),
      dialogName: "",
      rooms: []
    };
  },
  watch: {
    "dialogName": function(v, o) {
      this.refreshRooms();
    },
    "settings.main": function(v, o) {
      this.updateForm();
    }
  },
  methods: {
    join: function(option) {
      if (!option.name) return;
      this.connection.send("/join " + option.name);
      this.dialogName = "";
    },
    refreshRooms: function() {
      var self = this;
      this.connection.rooms({match: this.dialogName}, function(err, res) {
        if (!res.end) setTimeout(self.refreshRooms, 1500);
        self.n_rooms = res.n_rooms;
        self.rooms = res.rooms;
      });
    },
    updateForm: function(connectionId) {
      if (arguments.length && !connectionId) return this.settings.main = "#connection";
      var dialogName = this.settings.main.match(/create-dialog\/([^\/]+)/);
      this.connection = this.user.getConnection(connectionId);
      this.dialogName = dialogName ? dialogName[1] : "";
      this.refreshRooms();
    }
  },
  ready: function() {
    this.updateForm();
  }
};
</script>
