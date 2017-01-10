<template>
  <form autocomplete="off" class="convos-create-dialog" @submit.prevent>
    <div class="row">
      <div class="col s12">
        <h4>Join dialog</h4>
        <p v-if="user.connections.length">
          You can create a dialog with either a single user (by nick)
          or join a chat room (channel).
        </p>
      </div>
    </div>
    <div class="row" v-if="user.connections.length > 1">
      <md-select id="form_connection_id" :value.sync="connectionId" label="Select connection">
        <md-option :value="c.connection_id" :selected="connectionId == c.connection_id" v-for="c in user.connections">{{c.protocol}}-{{c.name}}</md-option>
      </md-select>
    </div>
    <div class="row">
      <md-input cols="s8 m9" :value.sync="dialogName">Room or nick</md-input>
      <div class="col input-field s4 m3">
        <button @click="join" class="btn waves-effect waves-light" :disabled="!dialogName.length">Chat</button>
      </div>
    </div>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
  </form>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {
      connectionId: "",
      dialogName: "",
      errors: [],
    };
  },
  watch: {
    "settings.main": function(v, o) {
      this.updateForm();
    }
  },
  methods: {
    connection: function() {
      return this.user.getConnection(this.connectionId);
    },
    join: function(option) {
      var command = this.dialogName;
      if (this.dialogName) this.connection().send("/join " + command);
      this.dialogName = "";
    },
    updateForm: function() {
      var dialogName = this.settings.main.match(/create-dialog\/([^\/]+)/);
      var connection = this.user.connections[0];
      this.connectionId = connection ? connection.connection_id : "";
      this.dialogName = dialogName ? dialogName[1] : "";
    }
  },
  ready: function() {
    this.updateForm();
  }
};
</script>
