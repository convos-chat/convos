package WebIrc;

=head1 NAME

WebIrc - IRC client on web

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Mojo::Base 'Mojolicious';
use WebIrc::Core;
use Mojo::Redis;

=head1 ATTRIBUTES

=head2 connection

Holds a L<Mojo::Redis> object.

=head2 core

Holds a L<WebIrc::Core> object.

=head2 archive

=cut

has 'connection' => sub { Mojo::Redis->new(server=>'127.0.0.1:6379') };
has 'core'       => sub { WebIrc::Core->new(redis=>shift->connection)};

# is this formatting done by a human or tidy..?
has 'archive'    => sub {
  my $self = shift;
  WebIrc::Core::Archive->new(  shift->config->{archive} ||
  $self->path_to('archive')) };

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;
  my $config = $self->plugin('Config');

  $self->plugin(OAuth2 => $config->{'OAuth2'});

  $self->add_helpers($config);
  $self->defaults(
    layout => 'default',
    logged_in => 0,
  );

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to(template => 'index');
  $r->get('/register')->to(template => 'user/register');
  $r->post('/register')->to('user#register');

  my $c=$r->bridge('/'); #->to('user#auth'); # disabling auth for now
  $c->route('/*server/:target')->to('client#view')->name('client_view');
  $c->route('/chat')->to('client#goto_view');
  $c->get('/settings')->to(template => 'user/settings')->name('settings');
  $c->post('/settings')->to('user#settings');
  $c->route('/archive')->to('archive#list');
  $c->route('/archive/search')->to('archive#search');
  $c->route('/archive/*server/:target')->to('archive#view');

  $c->websocket('/socket')->to('client#socket');

  # add NO_REDIS since batman is just going to do bootstrap now,
  # and Mojo::Redis seem to eat 100% cpu when the backend server
  # is not there...
  $self->core->start unless $ENV{'NO_REDIS'};
}

=head2 add_helpers

Will add thease helpers:

=over 4

=item oauth_connect_url

This is a modification of L<Mojolicious::Plugin::OAuth2/get_authorize_url>
since Jan Henning forgot to pass on the correct arguments.

=item page_header

Used to set/retrieve the page header used by C<layout/default.html.ep>

=back

=cut

sub add_helpers {
  my($self, $config) = @_;

  $self->helper(oauth_connect_url => sub {
    my($c, $use_current) = @_;
    $c->get_authorize_url(facebook => (
      $use_current ? () : (redirect_uri => $c->url_for('/account')->to_abs->to_string),
      scope => $config->{'OAuth2'}{'facebook'}{'scope'},
    ));
  });

  $self->helper(page_header => sub {
    $_[0]->stash('page_header', $_[1]) if @_ == 2;
    $_[0]->stash('title', Mojo::DOM->new($_[1])->all_text) if @_ == 2 and not $self->stash('title');
    $_[0]->stash('page_header') // 'Wirc';
  });
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

Marcus Ramberg

=cut

1;
