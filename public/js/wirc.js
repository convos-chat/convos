(function($) {
  var commands = {
    '/join': { append: ' #' },
    '/msg': { append: ' ' },
    '/me': { append: ' ' },
    '/nick': { append: ' ' },
    '/part': {}
  };

  IrcClient = function($scope, $http) {
    $scope.nick = '';
    $scope.messages = [];
    $scope.nick_list = [];
    $scope.targets = [];

    $http.get(window.location.href + '.json').success(function(data) {
      $.each(data, function(k, v) { $scope[k] = v });
    });

    // start a new chat or change to an existing #channel or nick
    $scope.changeTarget = function(server, target) {
      event.preventDefault();
      target = target.replace(/^\&/, '');
      window.console && console.log('changeTarget: ' + server + ' => ' + target);
      $('#targets ul li').removeClass('active');
      $(event.target).parents('li:first').addClass('active');
    };

    $scope.sendMessage = function() {
      if(!$scope.message) return;
      window.console && console.log('sendMessage ' + $scope.message);

      $scope.messages.push({
        text: $scope.message,
        sender: $scope.nick,
        className: 'icon-comment-alt'
      });

      $scope.message = '';
    };

    var $s = $scope; // keep $scope alive inside ready()
    $(document).ready(function() {
      $('#chat input[type="text"]').typeahead({
        source: Object.keys(commands),
        items: 5,
        matcher: function(item) {
          return item.toLowerCase().indexOf(this.query.toLowerCase()) == 0;
        },
        updater: function(item) {
          if(commands[item].append) {
            return item + commands[item].append;
          }

          $s.message = item;
          this.$element.parent().submit();
          return '';
        }
      });
    });
  };
})(jQuery);

// want to lazy load javascripts to prevent loading indicator
/*
(function(d){
  var js, id = 'facebook-jssdk'; if (d.getElementById(id)) {return;}
  js = d.createElement('script'); js.id = id; js.async = true;
  js.src = "//connect.facebook.net/en_US/all.js";
  d.getElementsByTagName('head')[0].appendChild(js);
}(document));
*/
