(function() {
  Convos.mixin.messageCanBeClosed = {
    props: ["dialog", "msg", "user"],
    methods: {
      close: function(e) {
        var type = this.msg.type;
        this.dialog.messages = this.dialog.messages.filter(function(msg) {
          return msg.type != type;
        });
      }
    }
  };
})();
