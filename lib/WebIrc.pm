package WebIrc;
use Mojo::Base 'Mojolicious';
use WebIrc::Core;
use Mojo::Redis;

has 'connection' => sub { Mojo::Redis->new(server=>'127.0.0.1:6379') };
has 'core'     => sub { WebIrc::Core->new(redis=>shift->connection)};

# This method will run once at server start
sub startup {
  my $self = shift;

  $self->plugin('OAuth2');

  $self->defaults(layout => 'default');
  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/')->to(template => 'index');
  $r->route('/login')->to('user#login');
  my $c=$r->bridge('/c')->to('user#auth')
  $r->route('/login')->to('user#login');
  $r->route('/register')->to('user#register');
  $c->route('/:channel')->to('client#view');
  $self->core->start;
}

1;
