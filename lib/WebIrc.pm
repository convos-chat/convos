package WebIrc;

=head1 NAME

WebIrc - IRC client on web

=head1 VERSION

0.01

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
use Mojo::Redis;
use File::Spec::Functions qw(catfile tmpdir);
use WebIrc::Core;
use WebIrc::Core::Util ();

our $VERSION = '0.01';
$ENV{WIRC_BACKEND_REV} ||= 0;

=head1 ATTRIBUTES

=head2 archive

Holds a L<WebIrc::Core::Archive> object.

=head2 core

Holds a L<WebIrc::Core> object.

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

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self   = shift;
  my $config = $self->plugin('Config');

  $config->{name} ||= 'Wirc';
  $config->{backend}{lock_file} ||= catfile(tmpdir, 'wirc-backend.lock');
  $config->{default_connection}{channels} = [ split /[\s,]/, $config->{default_connection}{channels} ] unless ref $config->{default_connection}{channels};
  $config->{default_connection}{server} = $config->{default_connection}{host} unless $config->{default_connection}{server}; # back compat

  $self->plugin('WebIrc::Plugin::Helpers');
  $self->secret($config->{secret} || die '"secret" is required in config file');
  $self->sessions->default_expiration(86400 * 30);
  $self->defaults(layout => 'default', logged_in => 0, VERSION => time, body_class => 'default');

  $self->plugin('AssetPack' => { rebuild => $config->{AssetPack}{rebuild} // 1 });
  $self->asset('webirc.css', '/sass/main.scss');
  $self->asset('webirc.js',
    '/js/jquery.min.js',
    '/js/jquery.hotkeys.min.js',
    '/js/jquery.fastbutton.min.js',
    '/js/jquery.nanoscroller.min.js',
    '/js/jquery.pjax.min.js',
    '/js/selectize.min.js',
    '/js/globals.js',
    '/js/jquery.doubletap.js',
    '/js/ws-reconnecting.js',
    '/js/jquery.wirc.js',
    '/js/wirc.chat.js',
  );

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to('client#route')->name('index');
  $r->get('/login')->to('user#login');
  $r->post('/login')->to('user#do_login');
  $r->get('/register')->to('user#register');
  $r->post('/register')->to('user#register');
  $r->get('/logout')->to('user#logout')->name('logout');

  my $private_r = $r->bridge('/')->to('user#auth');
  my $host_r = $private_r->any('/#server', [ server => $WebIrc::Core::Util::SERVER_NAME_RE ]);

  $private_r->websocket('/socket')->to('chat#socket')->name('socket');
  $private_r->get('/oembed')->to('oembed#generate', layout => undef)->name('oembed');
  $private_r->get('/conversations')->to('client#conversation_list', layout => undef)->name('conversation_list');
  $private_r->get('/notifications')->to('client#notification_list', layout => undef)->name('notification_list');
  $private_r->get('/command-history')->to('client#command_history');
  $private_r->post('/notifications/clear')->to('client#clear_notifications', layout => undef)->name('clear_notifications');
  $private_r->get('/settings')->to('user#settings')->name('settings');
  $private_r->post('/settings/connection')->to('user#add_connection')->name('connection.add');
  $private_r->post('/settings/profile')->to('user#edit_user')->name('user.edit');

  $host_r->get('/settings/delete')->to('user#delete_connection')->name('connection.delete');
  $host_r->post('/settings/edit')->to('user#edit_connection')->name('connection.edit');
  $host_r->get('/*target')->to('client#view')->name('view');
  $host_r->get('/')->to('client#view')->name('view.server');

  $self->hook(
    before_dispatch => sub {
      my $c = shift;
      $c->stash(errors => {});    # this need to be set up each time, since it's a ref
    }
  );

  if($config->{backend}{embedded}) {
    Mojo::IOLoop->timer(0, sub {
      $self->core->start;
    });
  }
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

Marcus Ramberg

=cut

1;
