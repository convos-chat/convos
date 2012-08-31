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

  $self->plugin('UrlWith');
  $self->secret($config->{secret} || die '"secret" is required in config file');
  $self->sessions->default_expiration(86400 * 30);
  $self->add_helpers($config);
  $self->defaults(
    layout => 'default',
    logged_in => 0,
  );

  # Normal route to controller
  my $r = $self->routes;
  $r->get('/')->to(template => 'index');
  $r->get('/login')->to(template => 'user/login');
  $r->get('/logout')->to('user#logout');
  $r->post('/login')->to('user#login');
  $r->get('/register')->to(template => 'user/register');
  $r->post('/register')->to('user#register');

  my $private_r=$r->bridge('/')->to('user#auth');
  $private_r->route('/settings')->to('user#settings')->name('settings');

  $private_r->route('/chat/#host')->to('client#view');
  $private_r->route('/chat/#host/:target')->to('client#view')->name('view');
  $private_r->route('/close/#host/:target')->to('client#close')->name('irc_close');
  $private_r->route('/disconnect/*host')->to('client#disconnect')->name('irc_disconnect');
  $private_r->route('/join/*host')->to('client#join')->name('irc_join');

  $private_r->route('/archive')->to('archive#list');
  $private_r->route('/archive/search')->to('archive#search');
  $private_r->route('/archive/:host/:target')->to('archive#view');
  $private_r->route('/archive/:host/:target')->to('archive#view');

  $private_r->websocket('/socket')->to('client#socket');

  $self->hook(before_dispatch => sub {
    my $c = shift;
    $c->stash(errors => {}); # this need to be set up each time, since it's a ref
  });

  $self->core->start;
  $self->proxy->start;
}

=head2 add_helpers

Will add thease helpers:

=head3 form_block

  %= form_block $name, class => [$str, ...] begin
  ...
  % end

The code above will create this markup:

  <div class="@$class" title="$error">
    ...
  </div>

In addition, <@$class> will contain "error" if C<$error> can be fetched from the
stash hash C<errors>, using C<$name> as key.

=head3 logf

  $c->logf($level => $format, @args);
  $c->logf(debug => 'yay %s', \%data);

Used to log more complex datastructures and to prevent logging C<undef>.

=head3 page_header

Used to set/retrieve the page header used by C<layout/default.html.ep>

=head3 redis

Returns a L<Mojo::Redis> object.

=cut

sub add_helpers {
  my($self, $config) = @_;

  $self->helper(logf => sub {
    use Data::Dumper;
    my($c, $level, $format, @args) = @_;
    local $Data::Dumper::Maxdepth = 2;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 1;

    for my $arg (@args) {
      if(ref($arg) =~ /^\w+$/) {
        $arg = Dumper($arg);
      }
      elsif(!defined $arg) {
        $arg = '__UNDEF__';
      }
    }

    $self->log->$level(sprintf $format, @args);
  });
  $self->helper(page_header => sub {
    $_[0]->stash('page_header', $_[1]) if @_ == 2;
    $_[0]->stash('title', Mojo::DOM->new($_[1])->all_text) if @_ == 2 and not $self->stash('title');
    $_[0]->stash('page_header') // $self->config->{'name'};
  });
  $self->helper(form_block => sub {
    my $content = pop;
    my($c, $field, %args) = @_;
    my $error = $c->stash('errors')->{$field} // '';
    my $classes = $args{class} ||= [];
    push @$classes, 'error' if $error;
    $c->tag(div =>
      class => join(' ', @$classes),
      title => $error,
      $content
    );
  });
  $self->helper(redis => sub { $self->redis });
}

=head1 COPYRIGHT

Nordaaker

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

Marcus Ramberg

=cut

1;
