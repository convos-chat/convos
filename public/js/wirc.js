(function($) {
  IrcClient = function($scope, $http) {
    $scope.channel_or_nick = '';
    $scope.nick = '';
    $scope.messages = [];
    $scope.nick_list = [];
    $scope.targets = [];

    $http.get(window.location.href + '.json').success(function(data) {
      $.each(data, function(k, v) { $scope[k] = v });
    });

    // start a new chat or change to an existing #channel or nick
    $scope.changeTarget = function() {
      if(this.href) { // triggered from jquery click handler
        $scope.channel_or_nick = this.href.match(/:\/\/(.*)/)[1];
        $('#changeTarget').submit();
        return false;
      }

      if($scope.channel_or_nick == '') return;
      window.console && console.log('changeTarget: ' + $scope.channel_or_nick);
      var $items = $('#targets ul li');
      var exists = false;

      $items.removeClass('active');
      $.each($scope.targets, function(i, item) {
        if(item.name == $scope.channel_or_nick) {
          item.active = true;
          $items.eq(i).addClass('active');
          exists = true;
        }
        else {
          item.active = false;
        }
      });

      if(!exists) {
        $scope.targets.push({
          name: $scope.channel_or_nick,
          className: 'active',
          active: true
        });
      }

      $scope.channel_or_nick = '';
    };

    $scope.sendMessage = function() {
      if(!$scope.message) return;
      window.console && console.log('sendMessage ' + $scope.message);

      console.log($scope);

      $scope.messages.push({
        text: $scope.message,
        sender: $scope.nick,
        className: 'icon-comment-alt'
      });

      console.log($scope.messages);

      $scope.message = '';
    };

    var $s = $scope; // keep it alive inside ready()
    $(document).ready(function() {
      $('#chat').find('a[href^="target"]').live('click', $s.changeTarget);
      $('#targets').find('a[href^="target"]').live('click', $s.changeTarget);
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
