package Convos::Plugin::Kiosk;
use Mojo::Base 'Convos::Plugin';

use Mojo::Util 'md5_sum';

use Convos::Plugin::Kiosk;

sub register {
  my ($self, $app, $config) = @_;

  $app->routes->get('/enter' => \&_kiosk);
}

sub _kiosk {
  my ($c, $args)    = @_;
  my $login         = $c->session('login');
  my $password      = md5_sum rand . time . $$;

  if ($login) {
    return $c->redirect_to('/');
  }

  $login ||= generate_login_name();
  my $user;
  my $connection;
  
  $c->delay(
    sub {
      my ($delay) = @_;
      $user = $c->app->core->user({email => "$login\@kiosk.convos.by"})->set_password($password);
      $c->session({email => $user->email});
      return $c->redirect_to('/');
    }
  );

}

sub generate_login_name {  
    my @set = ('0' ..'9');
    my $suffix = join '' => map $set[rand @set], 1 .. 4;
    "webchat_" . $suffix
}

1;
