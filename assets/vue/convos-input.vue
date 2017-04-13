<template>
  <div class="convos-input" :class="dialog.loading ? 'loading' : ''">
    <ul class="complete-dropdown dropdown-content" v-el:dropdown>
      <li :class="i == completeIndex ? 'active' : ''" v-for="(i, c) in completeList" v-show="completeList.length">
        <a href="#{{c}}" @click.prevent v-if="completeFormat == 'command'">{{c}}{{commands[c] ? " - " + commands[c].description : ""}}</a>
        <a href="#{{c}}" @click.prevent v-if="completeFormat == 'emoji'">{{{c.rich()}}} {{i ? emojiDescription(c) : ''}}</a>
        <a href="#{{c}}" @click.prevent v-if="completeFormat == 'nick'">{{c || "&nbsp;"}}</a>
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

Convos.commands.forEach(function(cmd) {
  if (!commands["/" + cmd.command]) commandList.push("/" + cmd.command);
  commands["/" + cmd.command] = cmd;
});

module.exports = {
  props:    ["dialog", "user"],
  computed: {
    placeholder: function() {
      try {
        var state = this.dialog.connection().state;
        if (this.dialog.loading) {
          return "Loading messages...";
        }
        else if (state == "connected") {
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
  watch: {
    "dialog.active": function(v, o) {
      if (v === true) this.focusInput();
    }
  },
  methods: {
    autocomplete: function(args) {
      var ta = this.$els.input;
      var padding = "";
      var i, pos, re, word;

      if (this.completeList.length) {
        this.completeIndex = args.up ? this.completeIndex - 1 : this.completeIndex + 1;
        if (this.completeIndex >= this.completeList.length) this.completeIndex = 0;
        if (this.completeIndex < 0) this.completeIndex = this.completeList.length - 1;
      }
      else {
        pos = ta.selectionStart;
        this.before = ta.value.substring(0, pos);
        this.after = ta.value.substring(pos);
        this.complete = this.before.match(/(\S)(\S*)$/) || ["", "", ""];
        this.completeIndex = 1;
        this.completeList = [];

        switch (this.complete[1]) {
          case "/":
            if (this.before.match(/^\S+$/)) {
              re = new RegExp("^" + this.complete[0], "i");
              this.completeFormat = "command";
              this.completeList = commandList.filter(function(i) { return i.match(re); });
            }
            break;
          case ":":
            re = [new RegExp("^" + this.complete[0], "i"), new RegExp(this.complete[2], "i")];
            this.completeFormat = "emoji";
            for (i = 0; i < emojis.length; i++) {
              if (emojis[i].match(re[0])) {
                this.completeList.unshift(emojis[i]);
                if (this.completeList.length > 30) break;
              }
              else if (emojis[i].match(re[1])) {
                this.completeList.push(emojis[i]);
                if (this.completeList.length > 30) break;
              }
            }
            break;
          default:
            var re = new RegExp("^" + this.complete[0], "i");
            this.completeFormat = "nick";
            this.completeList = this.participants().filter(function(i) { return i.match(re); });
        }

        this.before = this.before.substring(0, pos - this.complete[0].length);
        i = this.completeList.indexOf(this.complete[0]);
        this.completeList.unshift(i == -1 ? this.complete[0] : this.completeList.splice(i, 1));

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
        case 27: // esc
          this.completeList = [];
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
      return this.dialog.participants().sort(function(a, b) {
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
