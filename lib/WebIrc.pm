package WebIrc;
use Mojo::Base 'Mojolicious';
use WebIrc::Core;
use Mojo::Redis;

has 'core'     => sub { WebIrc::Core->new(redis=>$self->connection)};
has 'connection' => sub { Mojo::Redis->new(server=>'127.0.0.1:6379') }

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('OAuth2');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/')->to(template => 'frontpage');
  $r->route('/login')->to('user#login');
  $self->core->start;
}

1;
