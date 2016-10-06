<template>
  <div class="convos-input">
    <ul class="complete-dropdown dropdown-content" v-el:dropdown>
      <li :class="i == completeIndex ? 'active' : ''" v-for="(i, c) in completeList" v-if="completeList.length > 1">
        <a href="#{{c}}" @click.prevent v-if="completeFormat == 'command'">{{c}} - {{commands[c] ? commands[c].description : "Unknown command"}}</a>
        <a href="#{{c}}" @click.prevent v-if="completeFormat == 'emoji'">{{{c | markdown}}} {{i ? emojiDescription(c) : ''}}</a>
        <a href="#{{c}}" @click.prevent v-if="completeFormat == 'nick'">{{c}}</a>
      </li>
    </ul>
    <i @click="sendMessage" class="material-icons waves-effect waves-light">send</i>
    <textarea v-model="message" v-el:input class="materialize-textarea" :placeholder="placeholder" @keydown="keydown"></textarea>
  </div>
</template>
<script>
var emojis = Object.keys(emojione.emojioneList).filter(function(e) { return !e.match(/_tone/); }).sort();
var commandList = [];
var commands = {};

var _filter = function(list, match) {
  match = match.toLowerCase();
  return match.length ? list.filter(function(i) { return i.toLowerCase().indexOf(match) == 0; }) : list.slice(0);
};

Convos.commands.forEach(function(cmd) {
  if (!commands["/" + cmd.command]) commandList.push("/" + cmd.command);
  commands["/" + cmd.command] = cmd;

  (cmd.aliases || []).forEach(function(alias) {
    if (!commands["/" + alias]) commandList.push("/" + alias);
    commands["/" + alias] = cmd;
  });
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
    return {
      commands: commands,
      completeFormat: "nick",
      completeIndex: 0,
      completeList: [],
      message: ""
    };
  },
  methods: {
    autocomplete: function(args) {
      var ta = this.$els.input;
      var padding = "";
      var pos, word;

      if (this.completeList.length) {
        this.completeIndex = args.up ? this.completeIndex - 1 : this.completeIndex + 1;
        if (this.completeIndex >= this.completeList.length) this.completeIndex = 0;
        if (this.completeIndex < 0) this.completeIndex = this.completeList.length - 1;
      }
      else {
        pos = ta.selectionStart;
        this.before = ta.value.substring(0, pos);
        this.after = ta.value.substring(pos);
        this.complete = this.before.match(/(\S)(\S*)$/);
        this.completeIndex = 1;
        this.completeList = [];

        if (this.complete) {
          switch (this.complete[1]) {
            case "/":
              this.completeFormat = "command";
              if (this.before.match(/^\S+$/)) this.completeList = _filter(commandList, this.complete[0]);
              break;
            case ":":
              this.completeFormat = "emoji";
              this.completeList = _filter(emojis, this.complete[0]).splice(0, 40);
              break;
            default:
              this.completeFormat = "nick";
              this.completeList = _filter(this.participants(), this.complete[0]);
          }

          this.before = this.before.substring(0, pos - this.complete[0].length);

          if (this.completeList[0] != this.complete[0]) {
            this.completeList.unshift(this.complete[0]);
          }
        }

        if (this.completeList.length > 1) {
          var el = this.$els.dropdown;
          el.style.left = ta.offsetLeft + "px";
          el.style.bottom = (this.$el.offsetHeight - 4) + "px";
        }
      }

      if (this.complete && this.completeList.length > 1) {
        if (this.completeIndex) {
          padding = this.completeFormat == "nick" && this.before.match(/^\S*$/) ? ": " : " ";
        }
        word = this.completeList[this.completeIndex]
        pos = (this.before + word + padding).length;
        ta.value = this.before + word + padding + this.after;
        ta.setSelectionRange(pos, pos);
        this.$nextTick(function() {
          var $ul = $(ta).parent().find('ul');
          $ul.animate({scrollTop: $ul.find('.active').get(0).offsetTop - $ul.height() / 2}, 'fast');
        });
      }
    },
    emojiDescription: function(d) {
      return d.replace(/:/g, '');
    },
    focusInput: function() {
      if (!window.isMobile) this.$nextTick(function() { this.$els.input.focus(); });
    },
    keydown: function(e) {
      var c = e.keyCode || e.which;
      switch (c) {
        case 8: // backspace
          this.completeList = [];
          break;
        case 9: // tab
          e.preventDefault();
          this.autocomplete({up: e.shiftKey});
          break;
        case 13: // enter
          e.preventDefault(); // cannot have \n in the input field
          this.completeList = [];
          this.sendMessage();
          break;
        default:
          if (c >= 32) this.completeList = [];
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
      }).map(function(p) { return p.name });
    },
    sendMessage: function(e) {
      var msg = this.$els.input.value;
      var l = "localCmd" + msg.replace(/^\//, "").ucFirst();
      this.message = "";
      this.focusInput();
      this.$nextTick(function() { autosize.update(this.$els.input); });
      if ("localCmd" + msg != l && this[l]) return this[l](e);
      if (msg.length) this.dialog.connection().send(msg, this.dialog);
    }
  },
  ready: function() {
    var self = this;
    autosize(this.$els.input);

    this.$els.input.addEventListener("autosize:resized", function() {
      self.$emit("resized");
    });

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
