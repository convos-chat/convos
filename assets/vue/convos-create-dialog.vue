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
      <md-select @change="setConnection" :value="connectionId" label="Select connection">
        <md-option :value="c.connection_id" v-for="c in user.connections">{{c.protocol}}-{{c.name}}</md-option>
        <md-option value="">Create new connection...</md-option>
      </md-select>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <input v-el:input v-model="autocompleteValue" autocomplete="off" class="validate"
          debounce="200" placeholder="#channel_name" spellcheck="false" type="text"
          :disabled="errors.length ? true : false" :id="id"
          @blur="hasFocus=false" @focus="hasFocus=true" @keydown="keydown" @keyup="keyup">
        <label :for="id" class="active">Dialog name</label>
        <div class="alert" v-if="errors.length">
          Could not load rooms from
          <a v-link="connection.getDialog('').href()">{{connection.connection_id}}</a>:
          {{errors[0].message}}
        </div>
        <div class="autocomplete" :class="autocompleteOptions.length ? '' : 'hidden'">
          <a href="#join:{{room.name}}" class="title" :class="optionClass($index)" @click.prevent="join(room)" v-for="room in autocompleteOptions">
              <span class="badge"><i class="material-icons" v-if="room.n_users">person</i>{{room.n_users || "new"}}</span>
              <h6>{{room.name}}</h6>
              <p v-html="topic(room.topic)"></p>
          </a>
        </div>
        <p v-if="loaded"><small>Number of rooms: {{nRooms}}</small></p>
        <p v-if="!loaded && !errors.length"><small>Loading rooms... ({{nRooms}})</small></p>
      </div>
    </div>
  </form>
</template>
<script>
var mainRe = new RegExp("create-dialog\/([^\/]+)\/?([^\/]*)");
module.exports = {
  mixins: [Convos.mixin.autocomplete],
  props: ["user"],
  data: function() {
    return {
      connectionId: "",
      connection: null,
      errors: [],
      loaded: false,
      hasFocus: false,
      nRooms: 0,
      rooms: []
    };
  },
  computed: {
    autocompleteOptions: function() {
      var rooms = this.rooms;

      if (this.autocompleteValue) {
        rooms = [{name: this.autocompleteValue, topic: "Click here to create/join custom dialog"}].concat(rooms);
        if (rooms.length == 2) {
          rooms[0] = rooms.splice(1, 1, rooms[0])[0];
        }
        else if (rooms.length > 1 && rooms[0].name == rooms[1].name) {
          rooms.shift();
        }
      }

      return rooms;
    }
  },
  watch: {
    "autocompleteValue": function(v, o) {
      this.refreshRooms();
    },
    "settings.main": function(v, o) {
      if (v.match(mainRe)) this.updateForm();
    }
  },
  methods: {
    join: function(option) {
      if (!option.name || !this.connection) return;
      this.connection.send("/join " + option.name);
      this.autocompleteValue = "";
    },
    refreshRooms: function() {
      var self = this;
      if (this.tid) clearTimeout(this.tid);
      if (!this.connection) return;
      this.loaded = false;
      this.connection.rooms({match: this.autocompleteValue}, function(err, res) {
        if (!res.end) self.tid = setTimeout(self.refreshRooms, 1500);
        if (err) return self.errors = err;
        self.errors = [];
        self.loaded = res.end;
        self.nRooms = res.n_rooms;
        self.rooms = res.rooms;
      });
    },
    setConnection: function(cid, old) {
      if (!cid) return this.settings.main = "#connection";
      setTimeout(function() { this.updateForm(cid); }.bind(this), 500);
    },
    topic: function(str) {
      str = str.rich();
      if (!str) return "No topic.";
      if (str.length < 200) return str;
      return str.substr(0, 200).replace(/\S+$/, "") + "...";
    },
    updateForm: function(cid) {
      var path = this.settings.main.match(mainRe);
      this.connectionId = cid ? cid : path ? path[1] : "";
      if (this.connectionId) this.connection = this.user.getConnection(this.connectionId);
      this.autocompleteValue = path ? path[2] : "";
      this.errors = [];
      this.rooms = [];
      this.nRooms = 0;
      this.refreshRooms();
    }
  },
  ready: function() {
    this.id = Materialize.guid();
    this.$els.input.focusOnDesktop();
    this.updateForm();
  },
  destroyed: function() {
    if (this.tid) clearTimeout(this.tid);
  }
};
</script>
