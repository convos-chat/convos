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
use Mojo::Redis;

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

  $self->plugin('Mojolicious::Plugin::UrlWith');
  $self->plugin('WebIrc::Plugin::Helpers');
  $self->secret($config->{secret} || die '"secret" is required in config file');
  $self->sessions->default_expiration(86400 * 30);
  $self->defaults(layout => 'default', logged_in => 0, VERSION => time, body_class => 'default');

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to('client#route')->name('index');
  $r->post('/')->to('user#login_or_register');
  $r->any('/login')->to('user#login_or_register');
  $r->any('/register')->to('user#login_or_register', register_page => 1);
  $r->get('/logout')->to('user#logout')->name('logout');

  my $private_r = $r->bridge('/')->to('user#auth');
  my $host_r = $private_r->any('/#host', [ host => qr{\w+\.[^/]+} ]);

  $private_r->websocket('/socket')->to('chat#socket')->name('socket');
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

=head2 production_mode

This method will run L<WebIrc::Command::compile/compile_javascript> and
L<WebIrc::Command::compile/compile_stylesheet>.

=cut

sub production_mode {
  my $self = shift;

  unless($ENV{WIRC_BACKEND_REV}) {
    require WebIrc::Command::compile;
    WebIrc::Command::compile->new(app => $self)->compile_javascript->compile_stylesheet;
  }
}

=head2 development_mode

This will run L<WebIrc::Command::compile/compile_stylesheet> unless
L<Test::Mojo> is loaded. This allow you to start morbo like this:

  $ morbo script/web_irc -w public/sass -w lib

=cut

sub development_mode {
  my $self = shift;

  # ugly hack to prevent this from running when running unit tests
  unless($INC{'Test/Mojo.pm'}) {
    require WebIrc::Command::compile;
    WebIrc::Command::compile->new(app => $self)->compile_stylesheet;
  }
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

Marcus Ramberg

=cut

1;
