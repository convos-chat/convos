package Convos;

=head1 NAME

Convos - Multiuser IRC proxy with web interface

=head1 VERSION

0.3005

=head1 DESCRIPTION

Convos is to a multi-user IRC Proxy, that also provides a easy to use Web
interface. Feature list:

=over 4

=item * Always online

The backend server will keep you logged in and logs all the activity
in your archive.

=item * Archive

All chats will be logged and indexed, which allow you to search in
earlier conversations.

=item * Avatars

The chat contains profile pictures which can be retrieved from Facebook
or from gravatar.com.

=item * Include external resources

Links to images and video will be displayed inline. No need to click on
the link to view the data.

=back

=head2 Running convos

Convos has sane defaults so after installing L<Convos> you should be
able to just run it:

  # Install
  $ cpanm Convos
  # Run it
  $ convos backend &
  $ convos daemon

The above works, but if you have a lot of users you probably want to use
L<hypnotoad|Mojo::Server::Hypnotoad> instead of C<daemon>:

  $ hypnotoad $(which convos)

The command above will start a full featured, UNIX optimized, preforking
non-blocking webserver. Run the same command again, and the webserver
will L<hot reload|Mojo::Server::Hypnotoad/USR2> the source code without
loosing any connections.

=head2 Configuration

You can also customize the config by setting C<MOJO_CONFIG> before
running any of the commands above. Example:

  $ MOJO_CONFIG=$HOME/.convos.conf convos daemon

You can use L<https://github.com/Nordaaker/convos/blob/release/convos.conf>
as config file template.

=head2 Architecture principles

=over 4

=item * Keep the JS simple and manageable

=item * Use Redis to manage state / publish subscribe

=item * Archive logs in plain text format, use ack to search them.

=item * Bootstrap-based user interface

=back

=head1 RESOURCES

=over 4

=item * Homepage: L<http://convos.by>

=item * Project page: L<https://github.com/Nordaaker/convos>

=item * Icon: L<https://raw.github.com/Nordaaker/convos/master/public/image/icon.svg>

=item * Logo: L<https://raw.github.com/Nordaaker/convos/master/public/image/logo.svg>


=back

=head1 SEE ALSO

=over 4

=item * L<Convos::Archive>

Mojolicious controller for IRC logs.

=item * L<Convos::Client>

Mojolicious controller for IRC chat.

=item * L<Convos::User>

Mojolicious controller for user data.

=item * L<Convos::Core>

Backend functionality.

=back

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Redis;
use File::Spec::Functions qw( catdir catfile tmpdir );
use File::Basename qw( dirname );
use Convos::Core;
use Convos::Core::Util ();

our $VERSION = '0.3005';
$ENV{CONVOS_BACKEND_REV} ||= 0;

=head1 ATTRIBUTES

=head2 archive

Holds a L<Convos::Core::Archive> object.

=head2 cache

Holds a L<Mojolicious::Static> object pointing to a cache dir.
The directory is "/tmp/convos" by default.

=head2 core

Holds a L<Convos::Core> object.

=head2 backend_pid

The pid for the backend process, if running embedded.

=cut

has archive => sub {
  my $self = shift;
  Convos::Core::Archive->new($self->config->{archive} || $self->path_to('archive'));
};

has cache => sub {
  my $self = shift;
  my $dir = $self->config->{cache_dir} ||= catfile(tmpdir, 'convos');

  $self->log->info("Cache dir: $dir");
  mkdir $dir or die "mkdir $dir: $!" unless -d $dir;

  Mojolicious::Static->new(paths => [$dir]);
};

has core => sub {
  my $self = shift;
  my $core = Convos::Core->new;

  $core->redis->server($self->redis->server);
  $core;
};

has 'backend_pid';

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;
  my $config;

  $self->_from_cpan;
  $config = $self->plugin('Config');

  if(my $log = $config->{log}) {
    $self->log->level($log->{level}) if $log->{level};
    $self->log->path($log->{file}) if $log->{file} ||= $log->{path};
    delete $log->{handle}; # make sure it's fresh to file
  }

  $config->{name} ||= 'Convos';
  $config->{backend}{lock_file} ||= catfile(tmpdir, 'convos-backend.lock');
  $config->{default_connection}{channels} = [ split /[\s,]/, $config->{default_connection}{channels} ] unless ref $config->{default_connection}{channels};
  $config->{default_connection}{server} = $config->{default_connection}{host} unless $config->{default_connection}{server}; # back compat

  $self->cache; # make sure cache is ok
  $self->plugin('Convos::Plugin::Helpers');
  $self->secret($config->{secret} || die '"secret" is required in config file');
  $self->sessions->default_expiration(86400 * 30);
  $self->defaults(layout => 'default', logged_in => 0, body_class => 'default');

  $self->plugin('AssetPack' => { rebuild => $config->{AssetPack}{rebuild} // 1 });
  $self->asset('convos.css', '/sass/main.scss');
  $self->asset('convos.js',
    '/js/jquery.min.js',
    '/js/jquery.hotkeys.min.js',
    '/js/jquery.fastbutton.min.js',
    '/js/jquery.nanoscroller.min.js',
    '/js/jquery.pjax.min.js',
    '/js/selectize.min.js',
    '/js/globals.js',
    '/js/jquery.doubletap.js',
    '/js/ws-reconnecting.js',
    '/js/jquery.helpers.js',
    '/js/convos.chat.js',
  );

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to('client#route')->name('index');
  $r->get('/avatar/*id')->to('user#avatar')->name('avatar');
  $r->get('/login')->to('user#login', body_class => 'tactile')->name('login');
  $r->post('/login')->to('user#login', body_class => 'tactile');
  $r->get('/register/:invite', { invite => '' })->to('user#register', body_class => 'tactile')->name('register');;
  $r->post('/register/:invite', { invite => '' })->to('user#register', body_class => 'tactile');
  $r->get('/logout')->to('user#logout')->name('logout');

  my $private_r = $r->bridge('/')->to('user#auth');
  my $host_r = $private_r->any('/#server', [ server => $Convos::Core::Util::SERVER_NAME_RE ]);

  $private_r->websocket('/socket')->to('chat#socket')->name('socket');
  $private_r->get('/oembed')->to('oembed#generate', layout => undef)->name('oembed');
  $private_r->get('/conversations')->to('client#conversation_list', layout => undef)->name('conversation_list');
  $private_r->get('/notifications')->to('client#notification_list', layout => undef)->name('notification_list');
  $private_r->get('/command-history')->to('client#command_history');
  $private_r->post('/notifications/clear')->to('client#clear_notifications', layout => undef)->name('clear_notifications');
  $private_r->get('/convos')->to('client#convos')->name('convos');
  $private_r->get('/wizard')->to('user#wizard', body_class => 'tactile')->name('wizard');
  $private_r->get('/settings')->to('user#settings')->name('settings');
  $private_r->post('/settings/connection')->to('user#add_connection')->name('connection.add');
  $private_r->post('/settings/profile')->to('user#edit_user')->name('user.edit');

  $host_r->get('/settings/delete')->to('user#delete_connection')->name('connection.delete');
  $host_r->post('/settings/edit')->to('user#edit_connection')->name('connection.edit');
  $host_r->get('/*target')->to('client#view')->name('view');
  $host_r->get('/')->to('client#view')->name('view.server');

  if($config->{backend}{embedded}) {
    die "Can't run embedded, fork failed: $!" unless defined(my $pid = fork);
    return $self->backend_pid($pid) if $pid;
    my $loop=Mojo::IOLoop->singleton;
    $self->core->start;
    $0='convos backend';

    $SIG{$_}= 'DEFAULT' for  qw(INT TERM CHLD TTIN TTOU);
    $SIG{QUIT} = sub{ $loop->max_connnections(0)};
    $loop->start;
    exit 0;
  }
}

sub _from_cpan {
  my $self = shift;
  my $home = catdir dirname(__FILE__), 'Convos';
  my $config = catfile $home, 'convos.conf';

  -r $config or return;
  $self->home->parse($home);
  $self->static->paths->[0] = $self->home->rel_dir('public');
  $self->renderer->paths->[0] = $self->home->rel_dir('templates');
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013, Nordaaker.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

1;
