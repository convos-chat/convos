package WebIrc;
use Mojo::Base 'Mojolicious';
use WebIrc::Core;
use Mojo::Redis;

has 'connection' => sub { Mojo::Redis->new(server=>'127.0.0.1:6379') };
has 'core'       => sub { WebIrc::Core->new(redis=>shift->connection)};
has 'archive'    => sub {
  WebIrc::Core::Archive->new(  shift->config->{archive} ||
  $self->path_to('archive')) };

# This method will run once at server start
sub startup {
  my $self = shift;

  $self->plugin('OAuth2');

  $self->defaults(layout => 'default');
  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to(template => 'index');
  $r->get('/login')->to(template => 'user/login');
  $r->post('/login')->to('user#login');
  $r->get('/register')->to(template => 'user/register');
  $r->post('/register')->to('user#register');
  my $c=$r->bridge('/c')->to('user#auth');
  $c->route('/:server/:channel')->to('client#view');
  $c->websocket('/socket')->to('client#socket');
  $c->route('/archive')->to('archive#list');
  $c->route('/archive/search')->to('archive#search');
  $c->route('/archive/:server/:channel')->to('archive#view');

  $self->core->start;
}

1;
