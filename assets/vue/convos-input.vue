<template>
  <div class="convos-input">
    <!-- div class="actions">
      <a href="#attach" data-hint="Attach file"><i class="material-icons">attach_file</i></a>
      <a href="#webcam" data-hint="Take picture"><i class="material-icons">photo_camera</i></a>
      <a href="#emoji" data-hint="Insert emoji"><i class="material-icons">insert_emoticon</i></a>
      <a href="#send" @click="send" data-hint="Send message"><i class="material-icons">send</i></a>
    </div -->
    <i @click="send" class="material-icons waves-effect waves-light">send</i>
    <textarea v-model="message"
      v-el:input
      class="materialize-textarea"
      :placeholder="placeholder"
      @keyup.enter.prevent="send"
      @keydown="autocomplete"></textarea>
  </div>
</template>
<script>
var commands = [
  "/me ",
  "/help ",
  "/msg ",
  "/query ", // TODO
  "/join #",
  "/say ",
  "/nick ",
  "/whois ",
  "/names",
  "/close",
  "/part ",
  "/mode ", // TODO
  "/topic ",
  "/disconnect",
  "/connect"
];

module.exports = {
  props:    ["dialog", "user"],
  computed: {
    placeholder: function() {
      try {
        var state = this.dialog.connection ? this.dialog.connection.state : "connected";
        if (state == "connected") {
          return "What do you want to say to " + this.dialog.name + "?";
        } else {
          return 'Cannot send any message, since ' + state + '.';
        }
      } catch ( err ) {
        return "Please read the instructions on screen.";
      }
    }
  },
  data: function() {
    return {message: ""};
  },
  methods: {
    autocomplete: function(e) {
      var needle;

      // tab or shift
      if (e.keyCode != 9 && e.keyCode != 16) return delete this.matchList;
      if (e.keyCode == 16) return;

      e.preventDefault();

      if (!this.matchList) {
        this.pos = this.$els.input.selectionStart;
        this.before = this.message.substring(0, this.pos);
        needle = "";

        this.after = this.message.substring(this.pos);
        this.before = this.before.replace(/(\S+)\s*$/, function(all, n) { needle = n; return ""; });
        this.matchIndex = 0;
        this.matchList = [needle].concat(this.participants());

        if (!this.before.length) this.matchList = this.matchList.concat(commands);
        if (needle) {
          needle = new RegExp("^" + needle, "i");
          this.matchList = this.matchList.filter(function(m) { return m.match(needle); });
        }
      }

      this.matchIndex += e.shiftKey ? -1 : 1;
      if (this.matchIndex < 0)
        this.matchIndex = this.matchList.length - 1;
      if (this.matchIndex == this.matchList.length)
        this.matchIndex = 0;

      this.message = this.before + this.matchList[this.matchIndex] + this.after;

      if (this.after.length) {
        var pos = this.pos + this.matchList[this.matchIndex].length - 1;
        this.$nextTick(function() { this.$els.input.setSelectionRange(pos, pos); });
      }
    },
    localCmdHelp: function(e) {
      $("a.help").click();
    },
    localCmdJoin: function(e) {
      $("a.create-dialog").click();
    },
    participants: function() {
      return Object.values(this.dialog.participants).sort(function(a, b) {
        if (a.seen > b.seen) return -1;
        if (a.seen < b.seen) return 1;
        if (a.name > b.name) return -1;
        if (a.name < b.name) return 1;
        return 0;
      }).map(function(p) {
        return p.name + (this.after ? "" : this.before ? " " : ": ");
      }.bind(this));
    },
    send: function(e) {
      var m = this.message;
      var l = "localCmd" + m.replace(/^\//, "").ucFirst();
      var c = this.dialog.connection || this.user.connections[0];
      this.message = "";
      this.$els.input.focus();
      if ("localCmd" + m != l && this[l]) return this[l](e);
      if (c && m.length) c.send(m, this.dialog.connection ? this.dialog : "");
    }
  },
  ready: function() {
    var self = this;
    this.dialog.on("insertIntoInput", function(str) {
      if (str.indexOf('/') == 0) return self.$els.input.value = str; // command
      var val = self.$els.input.value.replace(/\s+$/, '');
      if (val.length) val += " "
      self.$els.input.value = val + str + " ";
    });
    this.$nextTick(function() { $("textarea", this.$el).focus(); });
  }
};
</script>
