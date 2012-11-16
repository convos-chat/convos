package WebIrc;

=head1 NAME

WebIrc - IRC client on web

=head1 SYNOPSIS

=head2 Production

  hypnotoad script/web_irc

=head2 Development

  morbo script/web_irc

=head1 DESCRIPTION

L<WebIrc> is a web frontend for IRC with additional features such as:

=over 4

=item Avatars

The chat contains profile pictures which can be retrieved from Facebook
or from gravatar.com.

=item Include external resources

Links to images and video will be displayed inline. No need to click on
the link to view the data.

=item Always online

The backend server will keep you logged in and logs all the activity
in your archive.

=item Archive

All chats will be logged and indexed, which allow you to search in
earlier conversations.

=back

=head1 SEE ALSO

=over 4

=item L<WebIrc::Archive>

Mojolicious controller for IRC logs.

=item L<WebIrc::Client>

Mojolicious controller for IRC chat.

=item L<WebIrc::User>

Mojolicious controller for user data.

=item L<WebIrc::Core>

Backend functionality.

=back

=cut

use Mojo::Base 'Mojolicious';
use WebIrc::Core;
use WebIrc::Proxy;
use Mojo::Redis;

=head1 ATTRIBUTES

=head2 redis

Holds a L<Mojo::Redis> object.

=head2 core

Holds a L<WebIrc::Core> object.

=head2 archive

=head2 proxy

Proxy manager

=cut

has redis => sub {
  my $log = $_[0]->app->log;
  my $redis = Mojo::Redis->new(server=>'127.0.0.1:6379',timeout=>600);
  $redis->on(error => sub { $log->error('[REDIS ERROR] ' .$_[1]) });
  $redis;
};
has core => sub { WebIrc::Core->new(redis=>shift->redis)};
has archive => sub {
  my $self = shift;
  WebIrc::Core::Archive->new(  $self->config->{archive} ||
    $self->path_to('archive'));
};
has proxy => sub { WebIrc::Proxy->new( core=> shift->core ) };

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;
  my $config = $self->plugin('Config');

  $self->plugin('Mojolicious::Plugin::UrlWith');
  $self->plugin('WebIrc::Plugin::Helpers');
  $self->secret($config->{secret} || die '"secret" is required in config file');
  $self->sessions->default_expiration(86400 * 30);
  $self->defaults(
    layout => 'default',
    logged_in => 0,
  );

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to('client#view')->name('index');
  $r->get('/show-hide', [format => 'css'])->to(template => 'show-hide');
  $r->get('/login')->to(template => 'user/login');
  $r->get('/logout')->to('user#logout');
  $r->post('/login')->to('user#login');
  $r->get('/register')->to(template => 'user/register');
  $r->post('/register')->to('user#register');

  my $private_r=$r->bridge('/')->to('user#auth');
  $private_r->route('/settings')->to('user#settings')->name('settings');

  $private_r->get('/history/:page')->to('client#history');
  $private_r->websocket('/socket')->to('client#socket');

  $self->hook(before_dispatch => sub {
    my $c = shift;
    $c->stash(errors => {}); # this need to be set up each time, since it's a ref
  });

  $self->core->start unless $ENV{SKIP_CONNECT};
  $self->proxy->start unless $ENV{DISABLE_PROXY};
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

Marcus Ramberg

=cut

1;
