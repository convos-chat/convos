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
use File::Spec::Functions qw(catfile tmpdir);
use WebIrc::Core;
use WebIrc::Proxy;
use Mojo::Redis;

=head1 ATTRIBUTES

=head2 archive

Holds a L<WebIrc::Core::Archive> object.

=head2 core

Holds a L<WebIrc::Core> object.

=head2 proxy

Holds a L<WebIrc::Proxy> object.

=cut

has archive => sub {
  my $self = shift;
  WebIrc::Core::Archive->new($self->config->{archive} || $self->path_to('archive'));
};

has core => sub {
  my $self = shift;
  my $core = WebIrc::Core->new;

  $core->redis->server($self->redis->server);
  $core;
};

has proxy => sub {
  my $self = shift;
  WebIrc::Proxy->new(core => $self->core);
};

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self   = shift;
  my $config = $self->plugin('Config');

  $config->{name} ||= 'Wirc';
  $config->{backend}{lock_file} ||= catfile(tmpdir, 'wirc-backend.lock');

  $self->plugin('Mojolicious::Plugin::UrlWith');
  $self->plugin('WebIrc::Plugin::Helpers');
  $self->secret($config->{secret} || die '"secret" is required in config file');
  $self->sessions->default_expiration(86400 * 30);
  $self->defaults(layout => 'default', logged_in => 0,);

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to('client#route')->name('index');
  $r->post('/')->to('user#login_or_register');
  $r->any('/login')->to('user#login_or_register');
  $r->any('/register')->to('user#login_or_register', register_page => 1);
  $r->get('/logout')->to('user#logout');

  my $private_r = $r->bridge('/')->to('user#auth');
  my $settings_r = $private_r->route('/settings')->to(target => $config->{name});
  $settings_r->get('/')->to('user#settings')->name('settings');
  $settings_r->get('/:cid', [cid => qr{\d+}])->to('user#settings')->name('connection.edit');
  $settings_r->post('/:cid', [cid => qr{\d+}])->to('user#edit_connection');
  $settings_r->post('/add')->to('user#add_connection')->name('connection.add');
  $settings_r->get('/:cid/delete')->to(template => 'user/delete_connection')->name('connection.delete');
  $settings_r->post('/:cid/delete')->to('user#delete_connection');

  $private_r->websocket('/socket')->to('chat#socket');

  $private_r->get('/v1/conversation-list')->to('client#conversation_list', layout => undef)->name('conversation_list');
  $private_r->get('/v1/:target/history/:offset', [page => qr{\d+}])->to('client#history', layout => undef);
  $private_r->get('/:cid/*target', [cid => qr{\d+}])->to('client#view')->name('channel.view');
  $private_r->get('/:cid', [cid => qr{\d+}])->to('client#view')->name('server.view');

  $self->hook(
    before_dispatch => sub {
      my $c = shift;
      $c->stash(errors => {});    # this need to be set up each time, since it's a ref
    }
  );

  Mojo::IOLoop->timer(0, sub {
    $self->_start_backend or return;
    $self->core->start;
    $self->proxy->start if $config->{backend}{proxy};
  });
}

sub _start_backend {
  my $self = shift;

  return 0 if $ENV{HYPNOTOAD_APP}; # TODO: Evil to use internal environment variables
  return 0 if -e $self->config->{backend}{lock_file};
  return 1;
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

Marcus Ramberg

=cut

1;
