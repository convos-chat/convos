<template>
  <div class="convos-input">
    <i @click="sendMessage" class="material-icons waves-effect waves-light">send</i>
    <textarea v-model="message" v-el:input
      class="materialize-textarea" :placeholder="placeholder"
      @keydown.tab.prevent @keydown.enter="sendMessage"></textarea>
  </div>
</template>
<script>
var commands = Convos.commands.map(function(cmd) { return cmd.command });

Convos.commands.forEach(function(cmd) {
  (cmd.aliases || []).forEach(function(a) { commands.push(a); });
});

module.exports = {
  props:    ["dialog", "user"],
  computed: {
    placeholder: function() {
      try {
        var state = this.dialog.connection().state;
        if (state == "connected") {
          var nick = this.dialog.connection().me.nick || this.user.email;
          return "What's on your mind " + nick + "?";
        }
        else {
          return "Cannot send any message, since " + state + ".";
        }
      } catch (err) {
        console.log("[convos-input]", err);
        return "Please read the instructions on screen.";
      }
    }
  },
  data: function() {
    return {completeVisible: false, message: ""};
  },
  methods: {
    autocompleteCommands: function() {
      return {
        match: /(^\/)(\S*)$/,
        replace: function(cmd) { return "/" + cmd + " "; },
        search: function(term, cb) {
          cb($.map(commands, function(word) {
            return word.indexOf(term) === 0 ? word : null;
          }));
        }
      };
    },
    autocompleteEmoji: function() {
      var emojis = Object.keys(emojione.emojioneList).filter(function(e) { return !e.match(/_tone/); }).sort();
      return {
        match: /(\B:)([\-+\w]*)$/,
        replace: function(emoji) { return emoji + " "; },
        template: function(emoji) { return emojione.toImage(emoji) + " " + emoji.replace(/:/g, ""); },
        search: function(term, cb) {
          cb($.map(emojis, function(emoji) {
            return emoji.indexOf(term) === 1 ? emoji : null;
          }));
        },
      };
    },
    autocompleteParticipants: function() {
      var self = this;
      return {
        match: /(^|\s)(\w+)$/,
        pre: "",
        replace: function(p) { return this.pre + p + " "; },
        search: function(term, cb, m) {
          this.pre = m[0].match(/^\s/) ? " " : "";
          var re = new RegExp(term, "i");
          cb($.map(self.participants(), function(word) {
            return word.match(re) ? word : null;
          }));
        }
      };
    },
    focusInput: function() {
      if (!window.isMobile()) this.$nextTick(function() { this.$els.input.focus(); });
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
      }).map(function(p) { return p.name });
    },
    sendMessage: function(e) {
      if (this.completeVisible) return;
      e.preventDefault(); // cannot have lineshift in the input field
      var m = this.message;
      var l = "localCmd" + m.replace(/^\//, "").ucFirst();
      this.message = "";
      this.focusInput();
      if ("localCmd" + m != l && this[l]) return this[l](e);
      if (m.length) this.dialog.connection().send(m, this.dialog);
    }
  },
  ready: function() {
    var self = this;
    autosize(this.$els.input);

    $(this.$els.input).textcomplete(
      [
        this.autocompleteCommands(),
        this.autocompleteEmoji(),
        this.autocompleteParticipants()
      ],
      {
        dropdownClassName: "dropdown-content textcomplete-dropdown",
        placement: "top",
        zIndex: 901
      }
    ).on("textComplete:show", function() { self.completeVisible = true; }
    ).on("textComplete:hide", function() { self.completeVisible = false; });

    this.dialog.on("active", this.focusInput);
    this.dialog.on("focusInput", this.focusInput);
    this.dialog.on("insertIntoInput", function(str) {
      if (str.indexOf("/") == 0) return self.$els.input.value = str; // command
      var val = self.$els.input.value.replace(/\s+$/, "");
      if (val.length) val += " "
      self.$els.input.value = val + str + " ";
      self.focusInput();
    });

    this.focusInput();
  }
};
</script>
