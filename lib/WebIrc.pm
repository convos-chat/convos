package WebIrc;
use Mojo::Base 'Mojolicious';
use WebIrc::Core;
use Mojo::Redis;

has 'connection' => sub { Mojo::Redis->new(server=>'127.0.0.1:6379') };
has 'core'       => sub { WebIrc::Core->new(redis=>shift->connection)};
has 'archive'    => sub {
  my $self = shift;
  WebIrc::Core::Archive->new(  shift->config->{archive} ||
  $self->path_to('archive')) };

# This method will run once at server start
sub startup {
  my $self = shift;
  my $config = $self->plugin('Config');

  $self->plugin(OAuth2 => $config->{'OAuth2'});

  $self->helper(oauth_connect_url => sub {
    my($c, $use_current) = @_;
    $c->get_authorize_url(facebook => (
      $use_current ? () : (redirect_uri => $c->url_for('/account')->to_abs->to_string),
      scope => $config->{'OAuth2'}{'facebook'}{'scope'},
    ));
  });

  $self->defaults(
    layout => 'default',
    logged_in => 0,
  );

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to(template => 'index');
  $r->get('/register')->to(template => 'user/register');
  $r->post('/register')->to('user#register');
  my $c=$r->bridge('/c')->to('user#auth');
  $c->route('/:server/:channel')->to('client#view');
  $c->websocket('/socket')->to('client#socket');
  $c->route('/archive')->to('archive#list');
  $c->route('/archive/search')->to('archive#search');
  $c->route('/archive/:server/:channel')->to('archive#view');

  # add NO_REDIS since batman is just going to do bootstrap now,
  # and Mojo::Redis seem to eat 100% cpu when the backend server
  # is not there...
  $self->core->start unless $ENV{'NO_REDIS'};
}

1;
