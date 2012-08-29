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

=cut

has redis => sub { Mojo::Redis->new(server=>'127.0.0.1:6379') };
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
  $self->secret(Mojo::JSON->new->encode($config));
  $self->plugin('Parallol');
  
  $self->add_helpers($config);
  $self->defaults(
    layout => 'default',
    logged_in => 0,
  );

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to(template => 'index');
  $r->get('/login')->to(template => 'user/login');
  $r->post('/login')->to('user#login');
  $r->get('/register')->to(template => 'user/register');
  $r->post('/register')->to('user#register');

  my $c=$r->bridge('/')->to('user#auth'); 
  $c->route('/setup')->to('client#setup');
  $c->get('/settings')->to(template => 'user/settings')->name('settings');
  $c->post('/settings')->to('user#settings');

  $c->route('/chat/#server')->to('client#view');
  $c->route('/chat/#server/:target')->to('client#view')->name('view');
  $c->route('/close/#server/:target')->to('client#close')->name('irc_close');
  $c->route('/disconnect/*server')->to('client#disconnect')->name('irc_disconnect');
  $c->route('/join/*server')->to('client#join')->name('irc_join');

  $c->route('/archive')->to('archive#list');
  $c->route('/archive/search')->to('archive#search');
  $c->route('/archive/:server/:target')->to('archive#view');
  $c->route('/archive/:server/:target')->to('archive#view');

  $c->websocket('/socket')->to('client#socket');

  $self->core->start;
  $self->proxy->start;
}

=head2 add_helpers

Will add thease helpers:

=over 4


=item page_header

Used to set/retrieve the page header used by C<layout/default.html.ep>

=cut

sub add_helpers {
  my($self, $config) = @_;


  $self->helper(page_header => sub {
    $_[0]->stash('page_header', $_[1]) if @_ == 2;
    $_[0]->stash('title', Mojo::DOM->new($_[1])->all_text) if @_ == 2 and not $self->stash('title');
    $_[0]->stash('page_header') // $self->config->{'name'};
  });

  $self->helper(redis => sub { $self->redis });
  $self->helper(steps => sub {
    my ($self,@steps)=$_;
    $self->render_later();
    Mojo::IOLoop->delay(@steps);
  });
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

Marcus Ramberg

=cut

1;
